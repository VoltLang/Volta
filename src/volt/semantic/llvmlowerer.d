// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.llvmlowerer;

import std.string : format;
import std.file : baseName;

import ir = volt.ir.ir;
import volt.ir.copy;
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
import volt.semantic.nested;


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
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status leave(ir.ThrowStatement t)
	{
		auto fn = retrieveFunctionFromObject(lp, t.location, "vrt_eh_throw");
		auto eRef = buildExpReference(t.location, fn, "vrt_eh_throw");
		t.exp = buildCall(t.location, eRef, [t.exp]);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Postfix postfix)
	{
		switch(postfix.op) {
		case ir.Postfix.Op.Index:
			return handleIndex(exp, postfix);
		default:
			return Continue;
		}
	}

	override Status enter(ref ir.Exp exp, ir.BinOp binOp)
	{
		switch(binOp.op) with(ir.BinOp.Op) {
		case AddAssign:
		case SubAssign:
		case MulAssign:
		case DivAssign:
		case ModAssign:
		case AndAssign:
		case OrAssign:
		case XorAssign:
		case CatAssign:
		case LSAssign:  // <<=
		case SRSAssign:  // >>=
		case RSAssign: // >>>=
		case PowAssign:
		case Assign:
			auto asPostfix = cast(ir.Postfix)binOp.left;
			if (asPostfix is null)
				return Continue;

			auto leftType = getExpType(lp, asPostfix.child, current);
			if (leftType !is null &&
			    leftType.nodeType == ir.NodeType.AAType &&
			    asPostfix.op == ir.Postfix.Op.Index) {
				acceptExp(asPostfix.child, this);
				acceptExp(asPostfix.arguments[0], this);
				acceptExp(binOp.right, this);

				if (binOp.op == ir.BinOp.Op.Assign) {
					return handleAssignAA(exp, binOp, asPostfix, cast(ir.AAType)leftType);
				} else {
					return handleOpAssignAA(exp, binOp, asPostfix, cast(ir.AAType)leftType);
				}
			}
			return Continue;
		default:
			return Continue;
		}
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

	override Status leave(ref ir.Exp exp, ir.AssocArray assocArray)
	{
		auto loc = exp.location;
		auto aa = cast(ir.AAType)getExpType(lp, exp, current);
		assert(aa !is null);

		auto statExp = buildStatementExp(loc);

		auto aaNewFn = retrieveFunctionFromObject(lp, loc, "vrt_aa_new");
		auto var = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, aa), buildCall(loc, aaNewFn, [
				buildTypeidSmart(loc, aa.value)
			], aaNewFn.name)
		);

		foreach (pair; assocArray.pairs) {
			auto store = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
				copyTypeSmart(loc, aa.value), pair.value
			);

			buildAAInsert(loc, lp, thisModule, current, statExp,
				 aa, var, pair.key, buildExpReference(loc, store), false, false
			);
		}

		statExp.exp = buildExpReference(loc, var);
		exp = statExp;

		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Unary uexp)
	{
		replaceArrayCastIfNeeded(exp.location, lp, current, uexp, exp);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		bool replaced = replaceNested(exp, eref, functionStack.length == 0 ? null : functionStack[$-1].nestedVariable);
		if (replaced) {
			return Continue;
		}

		auto fn = cast(ir.Function) eref.decl;
		if (fn is null) {
			return Continue;
		}
		if (functionStack.length == 0 || functionStack[$-1].nestedVariable is null) {
			return Continue;
		}
		bool isNested;
		PARENT: foreach (pf; functionStack) {
			foreach (nf; pf.nestedFunctions) {
				if (fn is nf) {
					isNested = true;
					break PARENT;
				}
			}
		}
		if (!isNested) {
			return Continue;
		}
		auto np = functionStack[$-1].nestedVariable;
		exp = buildCreateDelegate(exp.location, buildExpReference(np.location, np, np.name), eref);

		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		insertBinOpAssignsForNestedVariableAssigns(bs);
		super.enter(bs);
		return Continue;
	}

	protected Status handleIndex(ref ir.Exp exp, ir.Postfix postfix)
	{
		auto type = getExpType(lp, postfix.child, current);
		switch (type.nodeType) with(ir.NodeType) {
			case AAType:
				return handleIndexAA(exp, postfix, cast(ir.AAType)type);
			default:
				return Continue;
		}
	}

	protected Status handleIndexAA(ref ir.Exp exp, ir.Postfix postfix, ir.AAType aa)
	{
		auto loc = postfix.location;
		auto statExp = buildStatementExp(loc);

		auto var = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			buildPtrSmart(loc, aa), buildAddrOf(loc, postfix.child)
		);

		auto key = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, aa.key), postfix.arguments[0]
		);
		auto store = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, aa.value), null
		);

		buildAALookup(loc, lp, thisModule, current, statExp, aa, var,
			buildExpReference(loc, key, key.name),
			buildExpReference(loc, store, store.name)
		);

		statExp.exp = buildExpReference(loc, store);

		exp = statExp;

		return Continue;
	}

	protected Status handleAssign(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto asPostfix = cast(ir.Postfix)binOp.left;
		if (asPostfix is null)
			return Continue;

		auto leftType = getExpType(lp, asPostfix, current);
		if (leftType is null)
			return Continue;

		switch (leftType.nodeType) with(ir.NodeType) {
			case ArrayType:
				return handleAssignArray(exp, binOp, asPostfix, cast(ir.ArrayType)leftType);
			default:
				return Continue;
		}

	}

	protected Status handleAssignArray(ref ir.Exp exp, ir.BinOp binOp, ir.Postfix asPostfix, ir.ArrayType leftType)
	{
		auto loc = binOp.location;

		if (asPostfix.op != ir.Postfix.Op.Slice)
			return Continue;

		auto fn = getCopyFunction(loc, leftType);
		exp = buildCall(loc, fn, [asPostfix, binOp.right], fn.name);

		return Continue;
	}

	protected Status handleAssignAA(ref ir.Exp exp, ir.BinOp binOp, ir.Postfix asPostfix, ir.AAType aa)
	{
		auto loc = binOp.location;
		assert(asPostfix.op == ir.Postfix.Op.Index);
		auto statExp = buildStatementExp(loc);

		auto var = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			buildPtrSmart(loc, aa), buildAddrOf(loc, asPostfix.child)
		);

		auto key = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, aa.key), asPostfix.arguments[0]
		);
		auto value = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, aa.value), binOp.right
		);

		buildAAInsert(loc, lp, thisModule, current, statExp, aa, var,
				buildExpReference(loc, key, key.name),
				buildExpReference(loc, value, value.name)
		);

		statExp.exp = buildExpReference(loc, key, key.name);
		exp = statExp;

		return ContinueParent;
	}

	protected Status handleOpAssignAA(ref ir.Exp exp, ir.BinOp binOp, ir.Postfix asPostfix, ir.AAType aa)
	{
		auto loc = binOp.location;
		assert(asPostfix.op == ir.Postfix.Op.Index);
		auto statExp = buildStatementExp(loc);

		auto var = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			buildPtrSmart(loc, aa), null
		);
		buildExpStat(loc, statExp,
			buildAssign(loc, buildExpReference(loc, var, var.name), buildAddrOf(loc, asPostfix.child))
		);

		auto key = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, aa.key), null
		);
		buildExpStat(loc, statExp,
			buildAssign(loc, buildExpReference(loc, key, key.name), asPostfix.arguments[0])
		);
		auto store = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
			copyTypeSmart(loc, aa.value), null
		);

		buildAALookup(loc, lp, thisModule, current, statExp, aa, var,
			buildExpReference(loc, key, key.name),
			buildExpReference(loc, store, store.name)
		);

		buildExpStat(loc, statExp,
			buildBinOp(loc, binOp.op,
				buildExpReference(loc, store, store.name),
			 	binOp.right
			)
		);

		buildAAInsert(loc, lp, thisModule, current, statExp, aa, var,
			buildExpReference(loc, key, key.name),
			buildExpReference(loc, store, store.name),
			false
		);

		statExp.exp = buildExpReference(loc, store, store.name);
		exp = statExp;

		return ContinueParent;
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

		auto fnAlloc = lp.allocDgVariable;
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
					buildConstantSizeT(loc, lp, 1)
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
				buildConstantSizeT(loc, lp, size(loc, lp, ltype.base))
			),
			buildConstantInt(loc, 0),
			buildConstantFalse(loc)
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
						[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
					)
				)
			);
			buildReturnStat(loc, fn._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
		} else {
			buildReturnStat(loc, fn._body,
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
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
				buildConstantSizeT(loc, lp, size(loc, lp, type.base))
				),
			buildConstantInt(loc, 0),
			buildConstantFalse(loc)
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

		auto fnAlloc = lp.allocDgVariable;
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
				buildConstantSizeT(loc, lp, size(loc, lp, type.base))
			),
			buildConstantInt(loc, 0),
			buildConstantFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));


		args = [
			cast(ir.Exp)
			buildAdd(loc,
				buildExpReference(loc, allocated, allocated.name),
				buildBinOp(loc, ir.BinOp.Op.Mul,
					buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
					buildConstantSizeT(loc, lp, size(loc, lp, type.base))
				)
			),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, right, right.name), "length"),
				buildConstantSizeT(loc, lp, size(loc, lp, type.base))
			),
			buildConstantInt(loc, 0),
			buildConstantFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));


		if (isAssignment) {
			buildExpStat(loc, fn._body,
				buildAssign(loc,
					buildDeref(loc, buildExpReference(loc, left, left.name)),
					buildSlice(loc,
						buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
						[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
					)
				)
			);
			buildReturnStat(loc, fn._body, buildDeref(loc, buildExpReference(loc, left, left.name)));
		} else {
			buildReturnStat(loc, fn._body,
				buildSlice(loc,
					buildCastSmart(loc, buildPtrSmart(loc, type.base), buildExpReference(loc, allocated, allocated.name)),
					[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
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
						buildConstantSizeT(loc, lp, size(loc, lp, type.base))
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
		return retrieveFunctionFromObject(lp, loc, name);
	}

	ir.Function getLlvmMemCopy(Location loc)
	{
		auto name32 = "__llvm_memcpy_p0i8_p0i8_i32";
		auto name64 = "__llvm_memcpy_p0i8_p0i8_i64";
		auto name = V_P64 ? name64 : name32;
		return retrieveFunctionFromObject(lp, loc, name);
	}

	ir.Function getCMemCmp(Location loc)
	{
		return retrieveFunctionFromObject(lp, loc, "__llvm_memcmp");
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


void buildAAInsert(Location loc, LanguagePass lp, ir.Module thisModule, ir.Scope current,
		ir.StatementExp statExp, ir.AAType aa, ir.Variable var, ir.Exp key, ir.Exp value,
		bool buildif=true, bool aaIsPointer=true) {
	auto aaNewFn = retrieveFunctionFromObject(lp, loc, "vrt_aa_new");

	string name;
	if (aa.key.nodeType == ir.NodeType.PrimitiveType)
		name = "vrt_aa_insert_primitive";
	else
		name = "vrt_aa_insert_array";

	auto aaInsertFn = retrieveFunctionFromObject(lp, loc, name);

	ir.Exp varExp;
	if (buildif) {
		auto thenState = buildBlockStat(loc, statExp, current);
		varExp = buildExpReference(loc, var, var.name);
		buildExpStat(loc, thenState,
			buildAssign(loc,
				aaIsPointer ? buildDeref(loc, varExp) : varExp,
				buildCall(loc, aaNewFn, [
						buildTypeidSmart(loc, aa.value)
					], aaNewFn.name
				)
			)
		);

		varExp = buildExpReference(loc, var, var.name);
		buildIfStat(loc, statExp,
			buildBinOp(loc, ir.BinOp.Op.Is,
				aaIsPointer ? buildDeref(loc, varExp) : varExp,
				buildConstantNull(loc, buildVoidPtr(loc))
			),
			thenState
		);
	}

	varExp = buildExpReference(loc, var, var.name);
	auto call = buildExpStat(loc, statExp,
		buildCall(loc, aaInsertFn, [
			aaIsPointer ? buildDeref(loc, varExp) : varExp,
			buildAAKeyCast(loc, key, aa),
			buildCastToVoidPtr(loc, buildAddrOf(value))
		], aaInsertFn.name)
	);
}

void buildAALookup(Location loc, LanguagePass lp, ir.Module thisModule, ir.Scope current,
		ir.StatementExp statExp, ir.AAType aa, ir.Variable var, ir.Exp key, ir.Exp store) {
	string name;
	if (aa.key.nodeType == ir.NodeType.PrimitiveType)
		name = "vrt_aa_in_primitive";
	else
		name = "vrt_aa_in_array";
	auto inAAFn = retrieveFunctionFromObject(lp, loc, name);
	auto throwFn = retrieveFunctionFromObject(lp, loc, "vrt_eh_throw");

	auto thenState = buildBlockStat(loc, statExp, current);
	auto s = buildStorageType(loc, ir.StorageType.Kind.Immutable, buildChar(loc));
	canonicaliseStorageType(s);

	auto knfClass = retrieveClassFromObject(lp, loc, "KeyNotFoundException");
	auto throwableClass = retrieveClassFromObject(lp, loc, "Throwable");

	buildExpStat(loc, thenState,
		buildCall(loc, throwFn, [
			buildCastSmart(throwableClass,
				buildNew(loc, knfClass, "KeyNotFoundException", [
					buildConstantString(loc, `"Key does not exist"`)
				]),
			)
		], throwFn.name));

	buildIfStat(loc, statExp,
		buildBinOp(loc, ir.BinOp.Op.Equal,
			buildCall(loc, inAAFn, [
				buildDeref(loc, buildExpReference(loc, var, var.name)),
				buildAAKeyCast(loc, key, aa),
				buildCastToVoidPtr(loc,
					buildAddrOf(loc, store)
				)
			], inAAFn.name),
			buildConstantBool(loc, false)
		),
		thenState
	);
}


ir.Exp buildAAKeyCast(Location loc, ir.Exp key, ir.AAType aa)
{
	if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
		auto prim = cast(ir.PrimitiveType)aa.key;

		assert(prim.type != ir.PrimitiveType.Kind.Real);

		if (prim.type == ir.PrimitiveType.Kind.Float ||
			prim.type == ir.PrimitiveType.Kind.Double) {
			auto type = prim.type == ir.PrimitiveType.Kind.Double ?
				buildUlong(loc) : buildInt(loc);

			key = buildDeref(loc,
					buildCastSmart(loc, buildPtrSmart(loc, type), buildAddrOf(key))
			);
		}

		key = buildCastSmart(loc, buildUlong(loc), key);
	} else {
		key = buildCastSmart(loc, buildArrayTypeSmart(loc, buildVoid(loc)), key);
	}

	return key;
}

void replaceArrayCastIfNeeded(Location loc, LanguagePass lp, ir.Scope current, ir.Unary uexp, ref ir.Exp exp)
{
	if (uexp.op != ir.Unary.Op.Cast) {
		return;
	}

	auto toArray = cast(ir.ArrayType) realType(uexp.type);
	if (toArray is null) {
		return;
	}
	auto fromArray = cast(ir.ArrayType) getExpType(lp, uexp.value, current);
	if (fromArray is null) {
		return;
	}
	if (typesEqual(toArray, fromArray)) {
		return;
	}

	int fromSz = size(loc, lp, fromArray.base);
	int toSz = size(loc, lp, toArray.base);
	int biggestSz = fromSz > toSz ? fromSz : toSz;
	bool decreasing = fromSz > toSz;

	// ({
	auto sexp = new ir.StatementExp();
	sexp.location = loc;

	// auto arr = <exp>
	auto var = buildVariableSmart(loc, copyTypeSmart(loc, fromArray), ir.Variable.Storage.Function, "arr");
	var.assign = uexp.value;
	sexp.statements ~= var;

	//     vrt_throw_slice_error(arr.length, typeid(T).size);
	auto ln = buildAccess(loc, buildExpReference(loc, var), "length");
	auto sz = buildAccess(loc, buildTypeidSmart(loc, toArray.base), "size");
	ir.Exp fname = buildConstantString(loc, format(`"%s"`, baseName(exp.location.filename)));
	ir.Exp lineNum = buildConstantSizeT(loc, lp, cast(int) exp.location.line);
	auto rtCall = buildCall(loc, buildExpReference(loc, lp.throwSliceErrorFunction), [ln, sz, fname, lineNum]);
	buildExpStat(loc, sexp, rtCall);

	// auto _out = <castexp>
	auto _out = buildVariableSmart(loc, copyTypeSmart(loc, toArray), ir.Variable.Storage.Function, "_out");
	uexp.value = buildExpReference(loc, var);
	_out.assign = uexp;
	sexp.statements ~= _out;

	auto inLength = buildAccess(loc, buildExpReference(loc, var), "length");
	auto outLength = buildAccess(loc, buildExpReference(loc, _out), "length");
	ir.Exp lengthTweak;
	if (!decreasing) {
		lengthTweak = buildBinOp(loc, ir.BinOp.Op.Div, inLength, buildConstantSizeT(loc, lp, biggestSz));
	} else {
		lengthTweak = buildBinOp(loc, ir.BinOp.Op.Mul, inLength, buildConstantSizeT(loc, lp, biggestSz));
	}
	auto assign = buildAssign(loc, outLength, lengthTweak);
	buildExpStat(loc, sexp, assign);

	sexp.exp = buildExpReference(loc, _out);
	exp = sexp;
}

