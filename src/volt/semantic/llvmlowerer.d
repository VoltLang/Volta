// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.llvmlowerer;

import std.string : format;

import ir = volt.ir.ir;
import volt.ir.util;

import volt.exceptions;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
import volt.visitor.expreplace;

import volt.semantic.typer;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;


/**
 * Lowerers misc things needed by the LLVM backend.
 */
class LlvmLowerer : ScopeExpReplaceVisitor, Pass
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
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ref ir.Exp exp, ir.Postfix postfix)
	{
		if (postfix.op != ir.Postfix.Op.Call) {
			return Continue;
		}
		auto asPostfix = cast(ir.Postfix) postfix.child;
		if (asPostfix is null) {
			return Continue;
		}
		if (asPostfix.op != ir.Postfix.Op.CreateDelegate) {
			return Continue;
		}

		auto expRef = cast(ir.ExpReference) asPostfix.child;
		if (expRef is null) {
			return Continue;
		}

		auto asFunction = cast(ir.Function) asPostfix.memberFunction.decl;
		assert(asFunction !is null);

		if (asFunction.vtableIndex == -1) {
			return Continue;
		}

		string fieldName = format("_%s", asFunction.vtableIndex);

		auto asVar = cast(ir.Variable) expRef.decl;
		assert(asVar !is null);

		auto asTR = cast(ir.TypeReference) asVar.type;
		assert(asTR !is null);

		auto _class = cast(ir.Class) asTR.type;
		assert(_class !is null);

		auto vtableStore =  lookupOnlyThisScope(postfix.location, lp, _class.layoutStruct.myScope, "__vtable");
		assert(vtableStore !is null);

		auto vtableVariable = cast(ir.Variable) vtableStore.node;
		assert(vtableVariable !is null);

		auto preacc = buildAccess(postfix.location, expRef, "__vtable");

		auto access = buildAccess(postfix.location, preacc, fieldName);
		postfix.child = access;
		postfix.arguments ~= buildCast(postfix.location, buildVoidPtr(postfix.location), buildExpReference(postfix.location, asVar, asVar.name));

		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.BinOp binOp)
	{
		/**
		 * We do this on the leave function so we know that
		 * any children has been lowered as well.
		 */
		switch(binOp.op) {
		case ir.BinOp.Type.Assign:
			return handleAssign(exp, binOp);
		case ir.BinOp.Type.Cat:
			return handleCat(exp, binOp);
		case ir.BinOp.Type.CatAssign:
			return handleCatAssign(exp, binOp);
		case ir.BinOp.Type.NotEqual:
		case ir.BinOp.Type.Equal:
			return handleEqual(exp, binOp);
		default:
			return Continue;
		}
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
			throw CompilerPanic(loc, "OH GOD!");

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
			throw CompilerPanic(loc, "OH GOD!");

		auto fn = getConcatFunction(loc, leftArrayType, false);

		exp = buildCall(loc, fn, [binOp.left, binOp.right], fn.name);

		return Continue;
	}

	protected Status handleCatAssign(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto loc = binOp.location;

		auto leftType = getExpType(lp, binOp.left, current);
		auto leftArrayType = cast(ir.ArrayType)leftType;
		if (leftArrayType is null)
			throw CompilerPanic(loc, "OH GOD!");

		auto fn = getConcatFunction(loc, leftArrayType, true);
		exp = buildCall(loc, fn, [buildAddrOf(binOp.left), binOp.right], fn.name);

		return Continue;
	}

	protected Status handleEqual(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto loc = binOp.location;

		auto leftType = getExpType(lp, binOp.left, current);
		auto leftArrayType = cast(ir.ArrayType)leftType;
		if (leftArrayType is null)
			return Continue;

		auto fn = getArrayCmpFunction(loc, leftArrayType, binOp.op == ir.BinOp.Type.NotEqual);
		exp = buildCall(loc, fn, [binOp.left, binOp.right], fn.name);

		return Continue;
	}

	ir.Function getCopyFunction(Location loc, ir.ArrayType type)
	{
		if (type.mangledName is null)
			type.mangledName = mangle(null, type);

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

		ir.Exp length;
		auto typeSize = size(loc, lp, type.base);

		ir.Exp[] args = [
			cast(ir.Exp)
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, "left"), "ptr")),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, "right"), "ptr")),
			buildBinOp(loc, ir.BinOp.Type.Mul,
				buildAccess(loc, buildExpReference(loc, left, "left"), "length"),
				buildSizeTConstant(loc, lp, size(loc, lp, type.base))
				),
			buildConstantInt(loc, 0),
			buildFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, expRef, args));

		buildReturnStat(loc, fn._body, buildExpReference(loc, fn.type.params[0], "left"));

		return fn;
	}

	ir.Function getConcatFunction(Location loc, ir.ArrayType type, bool isAssignment)
	{
		if(type.mangledName is null)
			type.mangledName = mangle(null, type);

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
		
		ir.Variable left;
		if(isAssignment)
			left = addParam(loc, fn, buildPtrSmart(loc, type), "left");
		else
			left = addParamSmart(loc, fn, type, "left");
		auto right = addParamSmart(loc, fn, type, "right");

		auto fnAlloc = retrieveAllocDg(loc, lp, thisModule.myScope);
		auto allocExpRef = buildExpReference(loc, fnAlloc, fnAlloc.name);

		auto fnCopy = getLlvmMemCopy(loc);

		ir.Exp[] args;

		auto allocated = buildVarStatSmart(loc, fn._body, fn.myScope, buildVoidPtr(loc), "allocated");
		auto count = buildVarStatSmart(loc, fn._body, fn.myScope, buildSizeT(loc, lp), "count");

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
			buildBinOp(loc, ir.BinOp.Type.Mul,
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
				buildBinOp(loc, ir.BinOp.Type.Mul,
					buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
					buildSizeTConstant(loc, lp, size(loc, lp, type.base))
				)
			),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
			buildBinOp(loc, ir.BinOp.Type.Mul,
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
			type.mangledName = mangle(null, type);

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


		auto thenState = buildBlockStat(loc);
		buildReturnStat(loc, thenState, buildConstantBool(loc, notEqual));
		buildIfStat(loc, fn._body,
			buildBinOp(loc, ir.BinOp.Type.NotEqual,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildAccess(loc, buildExpReference(loc, right, right.name), "length")
			),
			thenState
		);

		buildReturnStat(loc, fn._body,
			buildBinOp(loc, notEqual ? ir.BinOp.Type.NotEqual : ir.BinOp.Type.Equal,
				buildCall(loc, memCmpExpRef, [
					buildCastSmart(loc, buildVoidPtr(loc), buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
					buildCastSmart(loc, buildVoidPtr(loc), buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
					cast(ir.Exp)buildBinOp(loc, ir.BinOp.Type.Mul,
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
		auto name32 = "llvm_memmove_p0i8_p0i8_i32";
		auto name64 = "llvm_memmove_p0i8_p0i8_i64";
		auto mangledName32 = "llvm.memmove.p0i8.p0i8.i32";
		auto mangledName64 = "llvm.memmove.p0i8.p0i8.i64";
		auto name = V_P64 ? name64 : name32;
		auto mangledName = V_P64 ? mangledName64 : mangledName32;

		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name, false);
		fn.mangledName = mangledName;
		addParam(loc, fn, buildVoidPtr(loc), "dst");
		addParam(loc, fn, buildVoidPtr(loc), "src");
		addParam(loc, fn, buildSizeT(loc, lp), "len");
		addParam(loc, fn, buildInt(loc), "align");
		addParam(loc, fn, buildBool(loc), "isvolatile");

		assert(fn !is null);
		return fn;
	}

	ir.Function getLlvmMemCopy(Location loc)
	{
		auto name32 = "llvm_memcpy_p0i8_p0i8_i32";
		auto name64 = "llvm_memcpy_p0i8_p0i8_i64";
		auto mangledName32 = "llvm.memcpy.p0i8.p0i8.i32";
		auto mangledName64 = "llvm.memcpy.p0i8.p0i8.i64";
		auto name = V_P64 ? name64 : name32;
		auto mangledName = V_P64 ? mangledName64 : mangledName32;

		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name, false);
		fn.mangledName = mangledName;
		addParam(loc, fn, buildVoidPtr(loc), "dst");
		addParam(loc, fn, buildVoidPtr(loc), "src");
		addParam(loc, fn, buildSizeT(loc, lp), "len");
		addParam(loc, fn, buildInt(loc), "align");
		addParam(loc, fn, buildBool(loc), "isvolatile");

		assert(fn !is null);
		return fn;
	}

	ir.Function getCMemCmp(Location loc)
	{
		auto name = "memcmp";

		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name, false);
		fn.mangledName = name;
		fn.type.ret = buildInt(loc);
		addParam(loc, fn, buildPtrSmart(loc, buildStorageType(loc, ir.StorageType.Kind.Const, buildVoid(loc))), "ptr1");
		addParam(loc, fn, buildPtrSmart(loc, buildStorageType(loc, ir.StorageType.Kind.Const, buildVoid(loc))), "ptr2");
		addParam(loc, fn, buildSizeT(loc, lp), "num");

		assert(fn !is null);
		return fn;
	}


	ir.Function lookupFunction(Location loc, string name)
	{
		// Lookup the copy function for this type of array.
		auto store = lookupOnlyThisScope(loc, lp, thisModule.myScope, name);
		if (store !is null && store.kind == ir.Store.Kind.Function) {
			assert(store.functions.length == 1);
			return store.functions[0];
		}
		return null;
	}
}
