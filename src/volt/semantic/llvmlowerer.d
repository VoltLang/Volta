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
import volt.visitor.scopereplacer;

import volt.semantic.typer;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.classify;
import volt.semantic.util;
import volt.semantic.nested;
import volt.semantic.classresolver;


/**
 * Lowers misc things needed by the LLVM backend.
 */
class LlvmLowerer : ScopeManager, Pass
{
public:
	LanguagePass lp;

	ir.Module thisModule;
	ScopeReplacer scopeReplacer;

	bool V_P64;

public:
	this(LanguagePass lp)
	{
		this.lp = lp;
		this.V_P64 = lp.settings.isVersionSet("V_P64");
		this.scopeReplacer = new ScopeReplacer();
	}

	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, scopeReplacer);
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.ReturnStatement ret)
	{
		if (ret.exp is null) {
			return Continue;
		}

		// find the function which the return statement belongs to
		auto fn = getParentFunction(current);

		// return type of the function is void
		auto retType = cast(ir.PrimitiveType) fn.type.ret;
		if (retType is null || retType.type != ir.PrimitiveType.Kind.Void) {
			return Continue;
		}

		auto expStat = buildExpStat(ret.location, ret.exp);
		ret.exp = null;

		auto owning = cast(ir.BlockStatement) current.node;
		assert(owning !is null);
		assert(owning.statements[$-1] is ret);
		owning.statements = owning.statements[0..$-1] ~ expStat ~ ret;

		return Continue;
	}

	override Status enter(ir.BlockStatement bs)
	{
		super.enter(bs);
		insertBinOpAssignsForNestedVariableAssigns(bs);
		/* Hoist declarations out of blocks and place them at the top of the function, to avoid
		 * alloc()ing in a loop. Name collisions aren't an issue, as the generated assign statements
		 * are already tied to the correct variable.
		 */
		if (functionStack.length == 0) {
			return Continue;
		}
		ir.Node[] newTopVars;
		for (size_t i = 0; i < bs.statements.length; ++i) {
			auto var = cast(ir.Variable) bs.statements[i];
			if (var is null) {
				continue;
			}
			auto l = bs.statements[i].location;
			if (var.assign !is null) {
				bs.statements[i] = buildExpStat(l, buildAssign(l, buildExpReference(l, var, var.name), var.assign));
				var.assign = null;
			} else {
				bs.statements = bs.statements[0 .. i] ~ bs.statements[i + 1 .. $];
			}
			newTopVars ~= var;
		}
		functionStack[$-1]._body.statements = newTopVars ~ functionStack[$-1]._body.statements;
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.Constant c)
	{
		// Convert interface Constants.
		auto iface = cast(ir._Interface) realType(c.type);
		if (iface !is null) {
			lp.actualize(iface);
			assert(iface.layoutStruct !is null);
			c.type = buildPtrSmart(c.location, buildPtrSmart(c.location, iface.layoutStruct));
		}
		return Continue;

	}

	override Status enter(ir.Variable v)
	{
		// Convert Interface variables to their internal struct.
		auto iface = cast(ir._Interface) realType(v.type);
		if (iface !is null) {
			lp.actualize(iface);
			assert(iface.layoutStruct !is null);
			v.type = buildPtrSmart(v.location, buildPtrSmart(v.location, iface.layoutStruct));
		}
		return Continue;
	}

	override Status enter(ir.Function fn)
	{
		super.enter(fn);
		// Convert Interfaces in parameters and return types to their internal struct.
		foreach (ref p; fn.type.params) {
			auto iface = cast(ir._Interface) realType(p);
			if (iface !is null) {
				assert(iface.layoutStruct !is null);
				p = buildPtrSmart(p.location, buildPtrSmart(p.location, iface.layoutStruct));
			}
		}
		auto retIface = cast(ir._Interface) realType(fn.type.ret);
		if (retIface !is null) {
			assert(retIface.layoutStruct !is null);
			fn.type.ret = buildPtrSmart(fn.location, buildPtrSmart(fn.location, retIface.layoutStruct));
		}
		return Continue;
	}

	override Status leave(ir.ThrowStatement t)
	{
		auto fn = lp.ehThrowFunc;
		auto eRef = buildExpReference(t.location, fn, "vrt_eh_throw");
		t.exp = buildCall(t.location, eRef, [t.exp,
			buildAccess(t.location, buildConstantString(t.location, t.location.filename, false), "ptr"),
			buildConstantSizeT(t.location, lp, cast(int)t.location.line)]);
		return Continue;
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
		/*
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
				buildTypeidSmart(loc, aa.value),
				buildTypeidSmart(loc, aa.key)
			], aaNewFn.name)
		);

		foreach (pair; assocArray.pairs) {
			auto key = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
				copyTypeSmart(loc, aa.key), pair.key
			);

			auto value = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
				copyTypeSmart(loc, aa.value), pair.value
			);

			buildAAInsert(loc, lp, thisModule, current, statExp,
				 aa, var, buildExpReference(loc, key), buildExpReference(loc, value), false, false
			);
		}

		statExp.exp = buildExpReference(loc, var);
		exp = statExp;

		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Unary uexp)
	{
		replaceInterfaceCastIfNeeded(exp.location, lp, current, uexp, exp);
		replaceArrayCastIfNeeded(exp.location, lp, current, uexp, exp);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Postfix postfix)
	{
		switch(postfix.op) {
		case ir.Postfix.Op.Index:
			return handleIndex(exp, postfix);
		default:
			break;
		}
		ir._Interface iface;
		if (isInterfacePointer(lp, postfix, current, iface)) {
			assert(iface !is null);
			auto cpostfix = cast(ir.Postfix) postfix.child;  // TODO: Calling returned interfaces directly.
			if (cpostfix is null || cpostfix.identifier is null) {
				throw makeExpected(exp.location, "interface");
			}
			auto store = lookupAsThisScope(lp, iface.myScope, postfix.location, cpostfix.identifier.value);
			if (store is null) {
				throw makeExpected(postfix.location, "method");
			}
			if (store.functions.length == 0) {
				throw makeExpected(postfix.location, "method");
			}
			if (store.functions.length > 1) {
				assert(false, "todo: generate default args and cross-ref");
			}
			//
			auto l = exp.location;
			auto handle = buildCastToVoidPtr(l, buildSub(l, buildCastSmart(l, buildPtrSmart(l, buildUbyte(l)), copyExp(cpostfix.child)), buildAccess(l, buildDeref(l, copyExp(cpostfix.child)), "__offset")));
			exp = buildCall(l, buildAccess(l, buildDeref(l, copyExp(cpostfix.child)), mangle(null, store.functions[0])), postfix.arguments ~ handle);
		}
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

		statExp.exp = buildExpReference(loc, value, value.name);
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
		auto rightType = getExpType(lp, binOp.right, current);

		auto arrayType = cast(ir.ArrayType)leftType;
		auto elementType = rightType;
		bool reversed = false;
		if (arrayType is null) {
			reversed = true;
			arrayType = cast(ir.ArrayType) rightType;
			elementType = leftType;
			if (arrayType is null) {
				throw panic(exp.location, "array concat failure");
			}
		}

		if (typesEqual(elementType, arrayType.base)) {
			// T[] ~ T
			ir.Function fn;
			if (reversed) {
				fn = getArrayPrependFunction(loc, arrayType, elementType);
			} else {
				fn = getArrayAppendFunction(loc, arrayType, elementType, false);
			}
			exp = buildCall(loc, fn, [binOp.left, binOp.right], fn.name);
		} else {
			// T[] ~ T[]
			auto fn = getArrayConcatFunction(loc, arrayType, false);
			exp = buildCall(loc, fn, [binOp.left, binOp.right], fn.name);
		}

		return Continue;
	}

	protected Status handleCatAssign(ref ir.Exp exp, ir.BinOp binOp)
	{
		auto loc = binOp.location;

		auto leftType = getExpType(lp, binOp.left, current);
		auto leftArrayType = cast(ir.ArrayType)realType(removeRefAndOut(leftType));
		if (leftArrayType is null)
			throw panic(binOp, "couldn't retrieve array type from cat assign.");

		// Currently realType is not needed here, but if it ever was
		// needed remember to realType leftArrayType.base as well,
		// since realType will remove enum's as well.
		auto rightType = removeRefAndOut(getExpType(lp, binOp.right, current));

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

	protected void replaceStaticArrayToArray(Location loc, LanguagePass lp, ir.Scope current, ir.ArrayType atype, ir.StaticArrayType stype, ir.Unary uexp, ref ir.Exp exp)
	{
		ir.Exp getLength() { return buildAccess(loc, copyExp(uexp.value), "length"); }

		// ({
		auto sexp = new ir.StatementExp();
		sexp.location = loc;

		// auto arr = new T[](sarr.length);
		auto var = buildVariableSmart(loc, copyTypeSmart(loc, atype), ir.Variable.Storage.Function, "arr");
		var.assign = buildNewSmart(loc, atype, getLength());
		sexp.statements ~= var;

		// arr[0 .. sarr.length] = sarr[0 .. sarr.length];
		auto left = buildSlice(loc, buildExpReference(loc, var, var.name), buildConstantSizeT(loc, lp, 0), getLength());
		auto right = buildSlice(loc, copyExp(uexp.value), buildConstantSizeT(loc, lp, 0), getLength());
		auto fn = getCopyFunction(loc, atype);
		buildExpStat(loc, sexp, buildCall(loc, fn, [left, right], fn.name));

		sexp.exp = buildExpReference(loc, var, var.name);
		exp = sexp;
	}

	protected void replaceInterfaceCastIfNeeded(Location loc, LanguagePass lp, ir.Scope current, ir.Unary uexp, ref ir.Exp exp)
	{
		if (uexp.op != ir.Unary.Op.Cast) {
			return;
		}
		auto iface = cast(ir._Interface) realType(uexp.type);
		if (iface is null) {
			return;
		}
		exp = buildAddrOf(loc, buildAccess(loc, uexp.value, mangle(iface)));
	}

	protected void replaceArrayCastIfNeeded(Location loc, LanguagePass lp, ir.Scope current, ir.Unary uexp, ref ir.Exp exp)
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
			auto stype = cast(ir.StaticArrayType) getExpType(lp, uexp.value, current);
			if (stype !is null) {
				replaceStaticArrayToArray(loc, lp, current, toArray, stype, uexp, exp);
			}
			return;
		}
		if (typesEqual(toArray, fromArray)) {
			return;
		}

		auto toClass = cast(ir.Class) realType(toArray.base);
		auto fromClass = cast(ir.Class) realType(fromArray.base);
		if (toClass !is null && fromClass !is null && isOrInheritsFrom(fromClass, toClass)) {
			return;
		}

		int fromSz = size(lp, fromArray.base);
		int toSz = size(lp, toArray.base);
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
		ir.Exp fname = buildConstantString(loc, format(`%s`, baseName(exp.location.filename)));
		ir.Exp lineNum = buildConstantSizeT(loc, lp, cast(int) exp.location.line);
		auto rtCall = buildCall(loc, buildExpReference(loc, lp.ehThrowSliceErrorFunc), [buildAccess(loc, fname, "ptr"), lineNum]);
		auto bs = buildBlockStat(loc, rtCall, current, buildExpStat(loc, rtCall));
		auto check = buildBinOp(loc, ir.BinOp.Op.NotEqual, buildBinOp(loc, ir.BinOp.Op.Mod, ln, sz), buildConstantSizeT(loc, lp, 0));
		auto _if = buildIfStat(loc, check, bs);
		sexp.statements ~= _if;

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

		ir.FunctionParam left, right;
		if(isAssignment)
			left = addParam(loc, fn, buildPtrSmart(loc, ltype), "left");
		else
			left = addParamSmart(loc, fn, ltype, "left");
		right = addParamSmart(loc, fn, rtype, "right");

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
				buildConstantSizeT(loc, lp, size(lp, ltype.base))
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

	ir.Function getArrayPrependFunction(Location loc, ir.ArrayType ltype, ir.Type rtype)
	{
		if (ltype.mangledName is null)
			ltype.mangledName = mangle(ltype);
		if(rtype.mangledName is null)
			rtype.mangledName = mangle(rtype);

		string name = "__prependArray" ~ ltype.mangledName ~ rtype.mangledName;

		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		fn = buildFunction(loc, thisModule.children, thisModule.myScope, name);
		fn.mangledName = fn.name;
		fn.isWeakLink = true;
		fn.type.ret = copyTypeSmart(loc, ltype);

		ir.FunctionParam left, right;
		right = addParamSmart(loc, fn, rtype, "left");
		left = addParamSmart(loc, fn, ltype, "right");

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
			buildAdd(loc, buildExpReference(loc, allocated, allocated.name), buildConstantSizeT(loc, lp, size(lp, ltype.base))),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, left.name), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, left, left.name), "length"),
				buildConstantSizeT(loc, lp, size(lp, ltype.base))
			),
			buildConstantInt(loc, 0),
			buildConstantFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, buildExpReference(loc, fnCopy, fnCopy.name), args));

		buildExpStat(loc, fn._body,
			buildAssign(loc,
				buildDeref(loc,
						buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
				),
				buildExpReference(loc, right, right.name)
			)
		);

		buildReturnStat(loc, fn._body,
			buildSlice(loc,
				buildCastSmart(loc, buildPtrSmart(loc, ltype.base), buildExpReference(loc, allocated, allocated.name)),
				[cast(ir.Exp)buildConstantSizeT(loc, lp, 0), buildExpReference(loc, count, count.name)]
			)
		);

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

		auto typeSize = size(lp, type.base);

		ir.Exp[] args = [
			cast(ir.Exp)
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, "left"), "ptr")),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, "right"), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, left, "left"), "length"),
				buildConstantSizeT(loc, lp, size(lp, type.base))
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
				buildConstantSizeT(loc, lp, size(lp, type.base))
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
					buildConstantSizeT(loc, lp, size(lp, type.base))
				)
			),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, right.name), "ptr")),
			buildBinOp(loc, ir.BinOp.Op.Mul,
				buildAccess(loc, buildExpReference(loc, right, right.name), "length"),
				buildConstantSizeT(loc, lp, size(lp, type.base))
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

		auto memCmp = lp.memcmpFunc;
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
						buildConstantSizeT(loc, lp, size(lp, type.base))
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
							buildTypeidSmart(loc, aa.value),
							buildTypeidSmart(loc, aa.key)
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
				buildAAKeyCast(loc, lp, current, key, aa),
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
		auto throwFn = lp.ehThrowFunc;

		auto thenState = buildBlockStat(loc, statExp, current);
		auto s = buildStorageType(loc, ir.StorageType.Kind.Immutable, buildChar(loc));
		canonicaliseStorageType(s);

		auto knfClass = retrieveClassFromObject(lp, loc, "KeyNotFoundException");
		auto throwableClass = retrieveClassFromObject(lp, loc, "Throwable");

		buildExpStat(loc, thenState,
			buildCall(loc, throwFn, [
				buildCastSmart(throwableClass,
					buildNew(loc, knfClass, "KeyNotFoundException", [
						buildConstantString(loc, `Key does not exist`)
						]),
					),
				buildAccess(loc, buildConstantString(loc, loc.filename), "ptr"),
				cast(ir.Exp)buildConstantSizeT(loc, lp, cast(int)loc.line)],
			throwFn.name));

		buildIfStat(loc, statExp,
			buildBinOp(loc, ir.BinOp.Op.Equal,
				buildCall(loc, inAAFn, [
					buildDeref(loc, buildExpReference(loc, var, var.name)),
					buildAAKeyCast(loc, lp, current, key, aa),
					buildCastToVoidPtr(loc,
						buildAddrOf(loc, store)
					)
				], inAAFn.name),
				buildConstantBool(loc, false)
			),
			thenState
		);
	}

	ir.Exp buildAAKeyCast(Location loc, LanguagePass lp, ir.Scope current, ir.Exp key, ir.AAType aa)
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
		} else if (realType(aa.key).nodeType == ir.NodeType.Struct || realType(aa.key).nodeType == ir.NodeType.Class) {
			key = buildStructAAKeyCast(loc, lp, current, key, aa);
		} else {
			key = buildCastSmart(loc, buildArrayTypeSmart(loc, buildVoid(loc)), key);
		}

		return key;
	}

	ir.Exp buildStructAAKeyCast(Location l, LanguagePass lp, ir.Scope current, ir.Exp key, ir.AAType aa)
	{
		auto concatfn = getArrayAppendFunction(l, buildArrayType(l, buildUlong(l)), buildUlong(l), false);
		auto keysfn = retrieveFunctionFromObject(lp, l, "vrt_aa_get_keys");
		auto valuesfn = retrieveFunctionFromObject(lp, l, "vrt_aa_get_values");

		// ulong[] array;
		auto atype = buildArrayType(l, buildUlong(l));
		auto sexp = buildStatementExp(l);
		auto var = buildVariableSmart(l, copyTypeSmart(l, atype), ir.Variable.Storage.Function, "array");
		sexp.statements ~= var;

		ir.ExpReference eref(ir.Variable v)
		{
			return buildExpReference(v.location, v, v.name);
		}

		void addElement(ir.Exp e, ref ir.Node[] statements)
		{
			auto call = buildCall(l, concatfn, [eref(var), e], concatfn.name);
			statements ~= buildExpStat(l, buildAssign(l, eref(var), call));
		}

		void delegate(ir.Aggregate) aggdg;  // Filled in with gatherAggregate, as DMD won't look forward for inline functions.

		void gatherType(ir.Type t, ir.Exp e, ref ir.Node[] statements)
		{
			switch (t.nodeType) {
			case ir.NodeType.ArrayType:
				auto atype = cast(ir.ArrayType)t;
				ir.ForStatement forStatement;
				ir.Variable index;
				buildForStatement(l, lp, current, buildAccess(l, e, "length"), forStatement, index);
				gatherType(realType(atype.base), buildIndex(l, e, eref(index)), forStatement.block.statements);
				sexp.statements ~= forStatement;
				break;
			case ir.NodeType.Struct:
			case ir.NodeType.Union:
				auto agg = cast(ir.Aggregate)t;
				aggdg(agg);
				break;
			case ir.NodeType.StorageType:
				auto stype = cast(ir.StorageType)t;
				gatherType(stype.base, e, statements);
				break;
			case ir.NodeType.PointerType:
			case ir.NodeType.PrimitiveType:
			case ir.NodeType.Class:
			case ir.NodeType.AAType:
				addElement(buildCastSmart(l, buildUlong(l), e), statements);
				break;
			default:
				throw panicUnhandled(t, format("aa aggregate key type '%s'", t.nodeType));
			}
		}

		void gatherAggregate(ir.Aggregate agg)
		{
			foreach (node; agg.members.nodes) {
				auto var = cast(ir.Variable) node;
				if (var is null) {
					continue;
				}
				if (var.name == "") {
					continue;
				}
				auto store = lookupOnlyThisScope(lp, agg.myScope, l, var.name);
				if (store is null) {
					continue;
				}
				auto rtype = realType(var.type);
				gatherType(rtype, buildAccess(l, copyExp(key), var.name), sexp.statements);
			}
		}

		aggdg = &gatherAggregate;

		gatherType(realType(aa.key), key, sexp.statements);

		// ubyte[] barray;
		auto oarray = buildArrayType(l, buildUbyte(l));
		auto outvar = buildVariableSmart(l, oarray, ir.Variable.Storage.Function, "barray");
		sexp.statements ~= outvar;

		// barray.ptr = cast(ubyte*) array.ptr;
		auto ptrcast = buildCastSmart(l, buildPtrSmart(l, buildUbyte(l)), buildAccess(l, eref(var), "ptr"));
		auto ptrass = buildAssign(l, buildAccess(l, eref(outvar), "ptr"), ptrcast);
		buildExpStat(l, sexp, ptrass);

		// barray.length = exps.length * typeid(ulong).size;
		auto lenaccess = buildAccess(l, eref(outvar), "length");
		auto mul = buildBinOp(l, ir.BinOp.Op.Mul, buildAccess(l, eref(var), "length"), buildConstantSizeT(l, lp, 8));
		auto lenass = buildAssign(l, lenaccess, mul);
		buildExpStat(l, sexp, lenass);

		sexp.exp = eref(outvar);
		return buildCastSmart(l, buildArrayType(l, buildVoid(l)), sexp);
	}
}

bool isInterfacePointer(LanguagePass lp, ir.Postfix pfix, ir.Scope current, out ir._Interface iface)
{
	pfix = cast(ir.Postfix) pfix.child;
	if (pfix is null) {
		return false;
	}
	auto t = getExpType(lp, pfix.child, current);
	auto ptr = cast(ir.PointerType) realType(t);
	if (ptr is null) {
		return false;
	}
	ptr = cast(ir.PointerType) realType(ptr.base);
	if (ptr is null) {
		return false;
	}
	auto _struct = cast(ir.Struct) realType(ptr.base);
	if (_struct is null) {
		return false;
	}
	iface = cast(ir._Interface) _struct.loweredNode;
	return iface !is null;
}
