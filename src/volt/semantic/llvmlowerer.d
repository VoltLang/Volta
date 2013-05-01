// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.llvmlowerer;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.scopemanager;

import volt.semantic.typer;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;
import volt.semantic.util;


/**
 * Lowerers misc things needed by the LLVM backend.
 */
class LlvmLowerer : ScopeManager, Pass
{
public:
	LanguagePass lp;

	ir.Module thisModule;

	bool V_P64;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
		this.V_P64 = lp.settings.isVersionSet("V_P64");
	}

	override void transform(ir.Module m)
	{
		/// @todo remove when MangledName attribute works.
		void h(string name, string mangled) {
			auto fn = retrieveFunctionFromObject(
				lp, m.myScope, m.location, name);
			fn.mangledName = mangled;
		}

		h("__llvm_memcmp", "memcmp");
		h("__llvm_memcpy_p0i8_p0i8_i32", "llvm.memcpy.p0i8.p0i8.i32");
		h("__llvm_memcpy_p0i8_p0i8_i64", "llvm.memcpy.p0i8.p0i8.i64");
		h("__llvm_memmove_p0i8_p0i8_i32", "llvm.memmove.p0i8.p0i8.i32");
		h("__llvm_memmove_p0i8_p0i8_i64", "llvm.memmove.p0i8.p0i8.i64");

		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status leave(ir.ThrowStatement t)
	{
		auto fn = retrieveFunctionFromObject(lp, thisModule.myScope, t.location, "vrt_eh_throw");
		auto eRef = buildExpReference(t.location, fn, "vrt_eh_throw");
		t.exp = buildCall(t.location, eRef, [t.exp]);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.BinOp binOp)
	{
		/**
		 * We do this on the leave function so we know that
		 * any children has been lowered as well.
		 */
		switch(binOp.op) {
		case ir.BinOp.Op.Assign:
			return handleAssign(exp, binOp);
		case ir.BinOp.Op.Cat:
			return handleCat(exp, binOp);
		case ir.BinOp.Op.CatAssign:
			return handleCatAssign(exp, binOp);
		case ir.BinOp.Op.NotEqual:
		case ir.BinOp.Op.Equal:
			return handleEqual(exp, binOp);
		default:
			return Continue;
		}
	}

	override Status visit(ref ir.Exp exp, ir.TraitsExp traits)
	{
		replaceTraits(exp, traits, lp, thisModule, current);
		return Continue;
	}

	protected Status handleAssign(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto loc = binOp.location;
		auto asPostfix = cast(ir.Postfix)binOp.left;

		if (asPostfix is null || asPostfix.op != ir.Postfix.Op.Slice)
			return Continue;

		auto leftType = getExpType(lp, asPostfix, current);
		auto leftArrayType = cast(ir.ArrayType)leftType;
		if (leftArrayType is null)
			throw panic(binOp, "OH GOD!");

		auto fn = getCopyFunction(loc, leftArrayType);

		exp = buildCall(loc, fn, [asPostfix, binOp.right], fn.name);

		return Continue;
	}

	protected Status handleCat(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto loc = binOp.location;

		auto leftType = getExpType(lp, binOp.left, current);
		auto leftArrayType = cast(ir.ArrayType)leftType;
		if (leftArrayType is null)
			throw panic(binOp, "OH GOD!");

		auto rightType = getExpType(lp, binOp.right, current);
		if (typesEqual(rightType, leftArrayType.base)) {
			// T[] ~ T
			auto fn = getArrayAppendFunction(loc, leftArrayType, rightType, false);
			exp = buildCall(loc, fn, [binOp.left, binOp.right], fn.name);
		} else {
			// T[] ~ T[]
			auto fn = getArrayConcatFunction(loc, leftArrayType, false);
			exp = buildCall(loc, fn, [binOp.left, binOp.right], fn.name);
		}

		return Continue;
	}

	protected Status handleCatAssign(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto loc = binOp.location;

		auto leftType = getExpType(lp, binOp.left, current);
		auto leftArrayType = cast(ir.ArrayType)leftType;
		if (leftArrayType is null)
			throw panic(binOp, "OH GOD!");

		auto rightType = getExpType(lp, binOp.right, current);
		if (typesEqual(rightType, leftArrayType.base)) {
			// T[] ~ T
			auto fn = getArrayAppendFunction(loc, leftArrayType, rightType, true);
			exp = buildCall(loc, fn, [buildAddrOf(binOp.left), binOp.right], fn.name);
		} else {
			auto fn = getArrayConcatFunction(loc, leftArrayType, true);
			exp = buildCall(loc, fn, [buildAddrOf(binOp.left), binOp.right], fn.name);
		}

		return Continue;
	}

	protected Status handleEqual(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto loc = binOp.location;

		auto leftType = getExpType(lp, binOp.left, current);
		auto leftArrayType = cast(ir.ArrayType)leftType;
		if (leftArrayType is null)
			return Continue;

		auto fn = getArrayCmpFunction(loc, leftArrayType, binOp.op == ir.BinOp.Op.NotEqual);
		exp = buildCall(loc, fn, [binOp.left, binOp.right], fn.name);

		return Continue;
	}

	ir.Function getArrayAppendFunction(Location loc, ir.ArrayType ltype, ir.Type rtype, bool isAssignment)
	{
		if (ltype.mangledName is null)
			ltype.mangledName = mangle(ltype);
		if(rtype.mangledName is null)
			rtype.mangledName = mangle(rtype);

		string name;
		if (isAssignment)
			name = "__appendArrayAssign" ~ ltype.mangledName ~ rtype.mangledName;
		else
			name = "__appendArray" ~ ltype.mangledName ~ rtype.mangledName;

		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
		fn.mangledName = fn.name;
		fn.isWeakLink = true;
		fn.type.ret = copyTypeSmart(loc, ltype);

		ir.FunctionParam left;
		if(isAssignment)
			left = addParam(loc, fn, buildPtrSmart(loc, ltype), "left");
		else
			left = addParamSmart(loc, fn, ltype, "left");
		auto right = addParamSmart(loc, fn, rtype, "right");

		auto fnAlloc = retrieveAllocDg(lp, thisModule.myScope, loc);
		auto allocExpRef = buildExpReference(loc, fnAlloc, fnAlloc.name);

		auto fnCopy = getLlvmMemCopy(loc);

		ir.Exp[] args;

		auto allocated = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildVoidPtr(loc), "allocated");
		auto count = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildSizeT(loc, lp), "count");

		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildExpReference(loc, count, count.name),
				buildAdd(loc,
					buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
					buildSizeTConstant(loc, lp, 1)
				)
			)
		);

		args = [
			cast(ir.Exp)
			buildTypeidSmart(loc, ltype.base),
			buildExpReference(loc, count, count.name)
		];

		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildExpReference(loc, allocated, allocated.name),
				buildCall(loc, allocExpRef, args)
			)
		);

		args = [
			cast(ir.Exp)
			buildExpReference(loc, allocated, allocated.name),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildSizeTConstant(loc, lp, size(loc, lp, ltype.base))
			),
			buildConstantInt(loc, 0),
			buildFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));

		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildDeref(loc,
					buildAdd(loc,
						buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
						buildAccess(loc, buildExpReference(loc, left, left.name), "length")
					)
				),
				buildExpReference(loc, right, right.name)
			)
		);

		if (isAssignment) {
			buildExpStat(loc, fn._body,
				buildAssign(loc,
					buildDeref(loc, buildExpReference(loc, left, left.name)),
					buildSlice(loc,
						buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
						[cast(ir.Exp)buildSizeTConstant(loc, lp, 0), buildExpReference(loc, count, count.name)]
					)
				)
			);
			buildReturnStat(loc, fn._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
		} else {
			buildReturnStat(loc, fn._body,
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildSizeTConstant(loc, lp, 0), buildExpReference(loc, count, count.name)]
				)
			);
		}

		return fn;
	}

	ir.Function getCopyFunction(Location loc, ir.ArrayType type)
	{
		if (type.mangledName is null)
			type.mangledName = mangle(type);

		auto name = "__copyArray" ~ type.mangledName;
		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
		fn.mangledName = fn.name;
		fn.isWeakLink = true;
		fn.type.ret = copyTypeSmart(loc, type);
		auto left = addParamSmart(loc, fn, type, "left");
		auto right = addParamSmart(loc, fn, type, "right");

		auto fnMove = getLlvmMemMove(loc);
		auto expRef = buildExpReference(loc, fnMove, fnMove.name);

		auto typeSize = size(loc, lp, type.base);

		ir.Exp[] args = [
			cast(ir.Exp)
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, "left"), "ptr")),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, "right"), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, left, "left"), "length"),
				buildSizeTConstant(loc, lp, size(loc, lp, type.base))
				),
			buildConstantInt(loc, 0),
			buildFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, expRef, args));

		buildReturnStat(loc, fn._body, buildExpReference(loc, fn.params[0], "left"));

		return fn;
	}

	ir.Function getArrayConcatFunction(Location loc, ir.ArrayType type, bool isAssignment)
	{
		if(type.mangledName is null)
			type.mangledName = mangle(type);

		string name;
		if(isAssignment)
			name = "__concatAssignArray" ~ type.mangledName;
		else
			name = "__concatArray" ~ type.mangledName;
		auto fn = lookupFunction(loc, name);
		if(fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
		fn.mangledName = fn.name;
		fn.isWeakLink = true;
		fn.type.ret = copyTypeSmart(loc, type);
		
		ir.FunctionParam left;
		if(isAssignment)
			left = addParam(loc, fn, buildPtrSmart(loc, type), "left");
		else
			left = addParamSmart(loc, fn, type, "left");
		auto right = addParamSmart(loc, fn, type, "right");

		auto fnAlloc = retrieveAllocDg(lp, thisModule.myScope, loc);
		auto allocExpRef = buildExpReference(loc, fnAlloc, fnAlloc.name);

		auto fnCopy = getLlvmMemCopy(loc);

		ir.Exp[] args;

		auto allocated = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildVoidPtr(loc), "allocated");
		auto count = buildVarStatSmart(loc, fn._body, fn._body.myScope, buildSizeT(loc, lp), "count");

		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildExpReference(loc, count, count.name),
				buildAdd(loc,
					buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
					buildAccess(loc, buildExpReference(loc, right, right.name), "length")
				)
			)
		);

		args = [
			cast(ir.Exp)
			buildTypeidSmart(loc, type.base),
			buildExpReference(loc, count, count.name)
		];

		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildExpReference(loc, allocated, allocated.name),
				buildCall(loc, allocExpRef, args)
			)
		);

		args = [
			cast(ir.Exp)
			buildExpReference(loc, allocated, allocated.name),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildSizeTConstant(loc, lp, size(loc, lp, type.base))
			),
			buildConstantInt(loc, 0),
			buildFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));


		args = [
			cast(ir.Exp)
			buildAdd(loc,
				buildExpReference(loc, allocated, allocated.name),
				buildBinOp(loc, ir.BinOp.Op.Mul,
					buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
					buildSizeTConstant(loc, lp, size(loc, lp, type.base))
				)
			),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, right, right.name), "length"),
				buildSizeTConstant(loc, lp, size(loc, lp, type.base))
			),
			buildConstantInt(loc, 0),
			buildFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));


		if (isAssignment) {
			buildExpStat(loc, fn._body,
				buildAssign(loc,
					buildDeref(loc, buildExpReference(loc, left, left.name)),
					buildSlice(loc,
						buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
						[cast(ir.Exp)buildSizeTConstant(loc, lp, 0), buildExpReference(loc, count, count.name)]
					)
				)
			);
			buildReturnStat(loc, fn._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
		} else {
			buildReturnStat(loc, fn._body,
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildSizeTConstant(loc, lp, 0), buildExpReference(loc, count, count.name)]
				)
			);
		}

		return fn;
	}

	ir.Function getArrayCmpFunction(Location loc, ir.ArrayType type, bool notEqual)
	{
		if(type.mangledName is null)
			type.mangledName = mangle(type);

		string name;
		if (notEqual)
			name = "__cmpNotArray" ~ type.mangledName;
		else
			name = "__cmpArray" ~ type.mangledName;
		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
		fn.mangledName = fn.name;
		fn.isWeakLink = true;
		fn.type.ret = buildBool(loc);

		auto left = addParamSmart(loc, fn, type, "left");
		auto right = addParamSmart(loc, fn, type, "right");

		auto memCmp = getCMemCmp(loc);
		auto memCmpExpRef = buildExpReference(loc, memCmp, memCmp.name);


		auto thenState = buildBlockStat(loc, fn, fn._body.myScope);
		buildReturnStat(loc, thenState, buildConstantBool(loc, notEqual));
		buildIfStat(loc, fn._body,
			buildBinOp(loc, ir.BinOp.Op.NotEqual,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildAccess(loc, buildExpReference(loc, right, right.name), "length")
			),
			thenState
		);

		buildReturnStat(loc, fn._body,
			buildBinOp(loc, notEqual ? ir.BinOp.Op.NotEqual : ir.BinOp.Op.Equal,
				buildCall(loc, memCmpExpRef, [
					buildCastSmart(loc, buildVoidPtr(loc), buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
					buildCastSmart(loc, buildVoidPtr(loc), buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
					cast(ir.Exp)buildBinOp(loc, ir.BinOp.Op.Mul,
						buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
						buildSizeTConstant(loc, lp, size(loc, lp, type.base))
					)
						
				]),
				buildConstantInt(loc, 0)
			)
		);

		return fn;
	}

	ir.Function getLlvmMemMove(Location loc)
	{
		auto name32 = "__llvm_memmove_p0i8_p0i8_i32";
		auto name64 = "__llvm_memmove_p0i8_p0i8_i64";
		auto name = V_P64 ? name64 : name32;
		return retrieveFunctionFromObject(lp, thisModule.myScope, loc, name);
	}

	ir.Function getLlvmMemCopy(Location loc)
	{
		auto name32 = "__llvm_memcpy_p0i8_p0i8_i32";
		auto name64 = "__llvm_memcpy_p0i8_p0i8_i64";
		auto name = V_P64 ? name64 : name32;
		return retrieveFunctionFromObject(lp, thisModule.myScope, loc, name);
	}

	ir.Function getCMemCmp(Location loc)
	{
		return retrieveFunctionFromObject(lp, thisModule.myScope, loc, "__llvm_memcmp");
	}

	/**
	 * This function is used to retrive cached
	 * versions of the helper functions.
	 */
	ir.Function lookupFunction(Location loc, string name)
	{
		// Lookup the copy function for this type of array.
		auto store = lookupOnlyThisScope(lp, thisModule.myScope, loc, name);
		if (store !is null && store.kind == ir.Store.Kind.Function) {
			assert(store.functions.length == 1);
			return store.functions[0];
		}
		return null;
	}
}
