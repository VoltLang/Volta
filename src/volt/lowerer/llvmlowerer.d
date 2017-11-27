/*#D*/
// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.llvmlowerer;

import watt.conv : toString;
import watt.text.format : format;
import watt.text.sink;
import watt.io.file : read, exists;

import ir = volta.ir;
import volta.util.copy;
import volta.util.util;

import volt.errors;
import volt.interfaces;
import volta.ir.location;
import volta.visitor.visitor;
import volt.visitor.scopemanager;
import volt.visitor.nodereplace;

import volt.lowerer.array;

import volt.semantic.util;
import volt.semantic.typer;
import volt.semantic.mangle;
import volt.semantic.lookup;
import volt.semantic.nested;
import volt.semantic.classify;
import volt.semantic.classresolver;
import volt.semantic.evaluate;
import volt.semantic.overload;

/*!
 * Next stop, backend! The LlvmLowerer visitor (and supporting functions) have a fairly
 * simple job to describe -- change any structure that the backend doesn't handle into
 * something composed of things the backend DOES know how to deal with. This can involve
 * turning keywords into function calls into the runtime, changing foreach statements
 * to for statements, and so on.
 */


/*!
 * Build a function call that inserts a value with a given key into a given AA, and
 * add it to a StatementExp.
 *
 * Params:
 *   loc: Nodes created in this function will be given this location.
 *   lp: The LanguagePass.
 *   thisModule: The module that the call will be living in.
 *   current: The scope at the point of call.
 *   statExp: The StatementExp to add the call to.
 *   aa: The type of the that we're inserting into.
 *   var: The Variable containing the instance of the AA being inserted in to.
 *   key: The key to associate the value with.
 *   value: The value we are inserting.
 *   buildif: Generate code to initialise the AA if it's needed.
 *   aaIsPointer: Is the AA being held as a pointer?
 */
void lowerAAInsert(ref in Location loc, LanguagePass lp, ir.Module thisModule, ir.Scope current,
		ir.StatementExp statExp, ir.AAType aa, ir.Variable var, ir.Exp key, ir.Exp value,
		LlvmLowerer lowerer, bool buildif=true, bool aaIsPointer=true) {
	auto aaNewFn = lp.aaNew;

	ir.Function aaInsertFn;
	if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
		aaInsertFn = lp.aaInsertPrimitive;
	} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
		aaInsertFn = lp.aaInsertArray;
	} else {
		aaInsertFn = lp.aaInsertPtr;
	}
	ir.Exp varExp;
	if (buildif) {
		auto thenState = buildBlockStat(/*#ref*/loc, statExp, current);
		varExp = buildExpReference(/*#ref*/loc, var, var.name);
		ir.Exp[] args = [ cast(ir.Exp)buildTypeidSmart(/*#ref*/loc, lp.tiTypeInfo, aa.value),
		                  cast(ir.Exp)buildTypeidSmart(/*#ref*/loc, lp.tiTypeInfo, aa.key)
		];
		buildExpStat(/*#ref*/loc, thenState,
			buildAssign(/*#ref*/loc,
				aaIsPointer ? buildDeref(/*#ref*/loc, varExp) : varExp,
				buildCall(/*#ref*/loc, aaNewFn, args, aaNewFn.name
				)
			)
		);
		varExp = buildExpReference(/*#ref*/loc, var, var.name);
		buildIfStat(/*#ref*/loc, statExp,
			buildBinOp(/*#ref*/loc, ir.BinOp.Op.Is,
				aaIsPointer ? buildDeref(/*#ref*/loc, varExp) : varExp,
				buildConstantNull(/*#ref*/loc, buildVoidPtr(/*#ref*/loc))
			),
			thenState
		);
	}

	varExp = buildExpReference(/*#ref*/loc, var, var.name);
	auto call = buildExpStat(/*#ref*/loc, statExp,
		buildCall(/*#ref*/loc, aaInsertFn, [
			aaIsPointer ? buildDeref(/*#ref*/loc, varExp) : varExp,
			lowerAAKeyCast(/*#ref*/loc, lp, thisModule, current, key, aa, lowerer),
			buildCastToVoidPtr(/*#ref*/loc, buildAddrOf(value))
		], aaInsertFn.name)
	);
}

/*!
 * Build code to lookup a key in an AA and add it to a StatementExp.
 *
 * Params:
 *   loc: Any Nodes created will be given this Location.
 *   lp: The LanguagePass.
 *   thisModule: The Module that the lookup will take place in.
 *   current: The Scope at the time of the lookup.
 *   statExp: The StatementExp to add the lookup to.
 *   aa: The type of the AA that we're performing a lookup on.
 *   var: The Variable that holds the AA.
 *   key: The key to lookup in the AA.
 *   store: A reference to a Variable of AA.value type, to hold the result of the lookup.
 */
void lowerAALookup(ref in Location loc, LanguagePass lp, ir.Module thisModule, ir.Scope current,
		ir.StatementExp statExp, ir.AAType aa, ir.Variable var, ir.Exp key, ir.Exp store,
		LlvmLowerer lowerer) {
	ir.Function inAAFn;
	if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
		inAAFn = lp.aaInPrimitive;
	} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
		inAAFn = lp.aaInArray;
	} else {
		inAAFn = lp.aaInPtr;
	}

	auto thenState = buildBlockStat(/*#ref*/loc, statExp, current);

	ir.Exp locstr = buildConstantStringNoEscape(/*#ref*/loc, format("%s:%s", loc.filename, loc.line));

	buildExpStat(/*#ref*/loc, thenState, buildCall(/*#ref*/loc, lp.ehThrowKeyNotFoundErrorFunc, [locstr]));

	buildIfStat(/*#ref*/loc, statExp,
		buildBinOp(/*#ref*/loc, ir.BinOp.Op.Equal,
			buildCall(/*#ref*/loc, inAAFn, [
				buildDeref(/*#ref*/loc, var),
				lowerAAKeyCast(/*#ref*/loc, lp, thisModule, current, key, aa, lowerer),
				buildCastToVoidPtr(/*#ref*/loc,
					buildAddrOf(/*#ref*/loc, store)
				)
			], inAAFn.name),
			buildConstantBool(/*#ref*/loc, false)
		),
		thenState
	);
}

/*!
 * Given an AA key, cast in such a way that it could be given to a runtime AA function.
 *
 * Params:
 *   loc: Any Nodes created will be given this location.
 *   lp: The LanguagePass.
 *   thisModule: The Module that this code is taking place in.
 *   current: The Scope where this code takes place.
 *   key: An expression holding the key in its normal form.
 *   aa: The AA type that the key belongs to.
 *
 * Returns: An expression casting the key.
 */
ir.Exp lowerAAKeyCast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
                      ir.Scope current, ir.Exp key, ir.AAType aa, LlvmLowerer lowerer)
{
	return lowerAACast(/*#ref*/loc, lp, thisModule, current, key, aa.key, lowerer);
}

ir.Exp lowerAAValueCast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
                      ir.Scope current, ir.Exp key, ir.AAType aa, LlvmLowerer lowerer)
{
	return lowerAACast(/*#ref*/loc, lp, thisModule, current, key, aa.value, lowerer);
}

ir.Exp lowerAACast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
                      ir.Scope current, ir.Exp key, ir.Type t, LlvmLowerer lowerer)
{
	if (t.nodeType == ir.NodeType.PrimitiveType) {
		auto prim = cast(ir.PrimitiveType)t;

		assert(prim.type != ir.PrimitiveType.Kind.Real);

		if (prim.type == ir.PrimitiveType.Kind.Float ||
			prim.type == ir.PrimitiveType.Kind.Double) {
			auto type = prim.type == ir.PrimitiveType.Kind.Double ?
				buildUlong(/*#ref*/loc) : buildInt(/*#ref*/loc);

			key = buildCastSmart(/*#ref*/loc, type, key);
		}

		key = buildCastSmart(/*#ref*/loc, buildUlong(/*#ref*/loc), key);
	} else {
		key = lowerStructOrArrayAACast(/*#ref*/loc, lp, thisModule, current, key, t, lowerer);
	}

	return key;
}

ir.Exp lowerAggregateAACast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
						ir.Scope current, ir.Exp key, ir.Aggregate st)
{
	auto sexp = buildStatementExp(/*#ref*/loc);
	// aggptr := new Aggregate;
	auto aggptr = buildVariableSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, st), ir.Variable.Storage.Function, "aggptr");
	aggptr.assign = buildNewSmart(/*#ref*/loc, st);
	sexp.statements ~= aggptr;
	// *aggptr = st;
	auto deref = buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, aggptr, aggptr.name));
	auto assign = buildAssign(/*#ref*/loc, deref, key);
	buildExpStat(/*#ref*/loc, sexp, assign);
	// return aggptr;
	sexp.exp = buildExpReference(/*#ref*/loc, aggptr, aggptr.name);
	return buildCastToVoidPtr(/*#ref*/loc, sexp);
}

/*!
 * Given an AA key that is a struct or an array,
 * cast it in such a way that it could be given to a runtime AA function.
 *
 * Params:
 *   loc: Any Nodes created will be given this location.
 *   lp: The LanguagePass.
 *   thisModule: The Module that this code is taking place in.
 *   current: The Scope where this code takes place.
 *   key: An expression holding the key/value in its normal form.
 *   t: The type of the key or value
 */
ir.Exp lowerStructOrArrayAACast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
                            ir.Scope current, ir.Exp key, ir.Type t, LlvmLowerer lowerer)
{
	if (t.nodeType != ir.NodeType.ArrayType) {
		auto st = cast(ir.Aggregate)realType(t);
		panicAssert(key, st !is null);
		return lowerAggregateAACast(/*#ref*/loc, lp, thisModule, current, key, st);
	}

	// Duplicate the array.
	auto beginning = buildConstantSizeT(/*#ref*/loc, lp.target, 0);
	ir.Exp end = buildArrayLength(/*#ref*/loc, lp.target, copyExp(key));
	ir.Exp dup = buildArrayDup(/*#ref*/loc, t, [copyExp(key), beginning, end]);

	// Cast the duplicate to void[].
	ir.Exp cexp = buildCastSmart(/*#ref*/loc, buildArrayType(/*#ref*/loc, buildVoid(/*#ref*/loc)), dup);
	acceptExp(/*#ref*/cexp, lowerer);
	return cexp;
}

/*!
 * Turn a PropertyExp into a call or member call as appropriate.
 *
 * Params:
 *   lp: The LanguagePass.
 *   exp: The expression to write the new call to.
 *   prop: The PropertyExp to lower.
 */
void lowerProperty(LanguagePass lp, ref ir.Exp exp, ir.PropertyExp prop)
{
	assert (prop.getFn !is null);

	auto name = prop.identifier.value;
	auto expRef = buildExpReference(/*#ref*/prop.loc, prop.getFn, name);

	if (prop.child is null) {
		exp = buildCall(/*#ref*/prop.loc, expRef, null);
	} else {
		exp = buildMemberCall(/*#ref*/prop.loc,
		                      prop.child,
		                      expRef, name, null);
	}
}

//! Lower a composable string, either at compile time, or calling formatting functions with a sink.
void lowerComposableString(LanguagePass lp, ir.Scope current, ir.Function func, ref ir.Exp exp,
ir.ComposableString cs, LlvmLowerer lowerer)
{
	// `new "blah ${...} blah"`
	auto loc = cs.loc;
	auto sexp = buildStatementExp(/*#ref*/loc);
	if (func.composableSinkVariable is null) {
		func.composableSinkVariable = buildVariableAnonSmartAtTop(lp.errSink, /*#ref*/loc,
			func._body, lp.sinkStore, null);
	}
	auto sinkStoreVar = func.composableSinkVariable;
	auto sinkVar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, lp.sinkType,
		buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.sinkInit, lp.sinkInit.name), [
			cast(ir.Exp)buildExpReference(/*#ref*/loc, sinkStoreVar, sinkStoreVar.name)]));
	StringSink constantSink;
	foreach (component; cs.components) {
		auto c = component.toConstantChecked();
		if (c !is null && c._string.length > 0) {
			// A constant component, like the string literal portions.
			addConstantComposableStringComponent(lp.target, constantSink.sink, c);
		} else {
			// Empty the constant sink, and place that into the sink proper.
			string str = constantSink.toString();
			if (str.length > 0) {
				lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, str), sexp, sinkVar);
			}
			constantSink.reset();
			// ...and then route the runtime expression to the right place.
			void simpleAdd(ir.Node n)
			{
				auto exp = cast(ir.Exp)n;
				if (exp !is null) {
					buildExpStat(/*#ref*/loc, sexp, exp);
				} else {
					sexp.statements ~= n;
				}
			}
			version (D_Version2) {
				auto dgt = &simpleAdd;
			} else {
				auto dgt = simpleAdd;
			}
			auto rtype = realType(getExpType(component), false);
			bool _string = isString(rtype);
			bool _char = isChar(rtype);
			if (_string) {
				/* We treat top level strings differently to strings in arrays etc. (no " at top level)
				 * Special casing it here seems the simplest solution.
				 */
				lowerComposableStringStringComponent(component, sexp, sinkVar, dgt);
			} else if (_char) {
				/* Same deal as the strings. */
				auto outExp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.formatDchar, lp.formatDchar.name), [
										buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name),
										buildCast(/*#ref*/loc, buildDchar(/*#ref*/loc), copyExp(component))]);
				dgt(outExp);
			} else {
				lowerComposableStringComponent(lp, current, component, sexp, sinkVar, dgt, lowerer);
			}
		}
	}
	// Empty the constant sink before finishing up.
	string str = constantSink.toString();
	if (str.length > 0) {
		lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, str), sexp, sinkVar);
	}

	sexp.exp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.sinkGetStr, lp.sinkGetStr.name), [
		cast(ir.Exp)buildExpReference(/*#ref*/loc, sinkStoreVar, sinkStoreVar.name)]);
	exp = sexp;
}

//! Used by the composable string lowering code.
alias NodeConsumer = void delegate(ir.Node);

//! Dispatch a composable string component to the right function.
void lowerComposableStringComponent(LanguagePass lp, ir.Scope current,
	ir.Exp e, ir.StatementExp sexp, ir.Variable sinkVar, NodeConsumer dgt, LlvmLowerer lowerer)
{
	auto type = realType(getExpType(e), /*stripEnum*/false);
	if (e.nodeType == ir.NodeType.Constant) {
		auto c = e.toConstantFast();
		if (c.fromEnum !is null) {
			type = c.fromEnum;
		}
	}
	switch (type.nodeType) {
	case ir.NodeType.Enum:
		lowerComposableStringEnumComponent(lp, current, type.toEnumFast(), e, sexp, sinkVar, dgt);
		return;
	case ir.NodeType.PointerType:
		lowerComposableStringPointerComponent(lp, e, sexp, sinkVar, dgt);
		break;
	case ir.NodeType.ArrayType:
		if (isString(type)) {
			lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/e.loc, "\""), sexp, sinkVar, dgt);
			lowerComposableStringStringComponent(e, sexp, sinkVar, dgt);
			lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/e.loc, "\""), sexp, sinkVar, dgt);
			return;
		}
		lowerComposableStringArrayComponent(lp, current, e, sexp, sinkVar, dgt, lowerer);
		break;
	case ir.NodeType.AAType:
		auto aatype = type.toAATypeFast();
		lowerComposableStringAAComponent(lp, current, e, aatype, sexp, sinkVar, dgt, lowerer);
		break;
	case ir.NodeType.PrimitiveType:
		auto pt = type.toPrimitiveTypeFast();
		lowerComposableStringPrimitiveComponent(lp, current, e, pt, sexp, sinkVar, dgt);
		break;
	case ir.NodeType.Union:
	case ir.NodeType.Struct:
	case ir.NodeType.Class:
		auto agg = cast(ir.Aggregate)type;
		auto store = lookupInGivenScopeOnly(lp, agg.myScope, /*#ref*/e.loc, "toString");
		ir.Function[] functions;
		if (store !is null && store.functions.length > 0) {
			ir.Type[] args;
			auto toStrFn = selectFunction(lp.target, store.functions, args, /*#ref*/e.loc, DoNotThrow);
			if (toStrFn !is null && isString(toStrFn.type.ret)) {
				ir.Postfix _call = buildMemberCall(/*#ref*/e.loc, copyExp(e), buildExpReference(/*#ref*/e.loc, toStrFn), "toString", null);
				auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/e.loc, current, sexp, buildString(/*#ref*/e.loc), _call);
				lowerComposableStringStringComponent(buildExpReference(/*#ref*/e.loc, var, var.name), sexp, sinkVar, dgt);
				break;
			}
		}
		lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/e.loc, agg.name), sexp, sinkVar, dgt);
		break;
	default:
		assert(false);  // Should be caught in extyper.
	}
}

//! Lower a primitive type component of a composable string.
void lowerComposableStringPrimitiveComponent(LanguagePass lp, ir.Scope current, ir.Exp e,
	ir.PrimitiveType pt, ir.StatementExp sexp, ir.Variable sinkVar, NodeConsumer dgt)
{
	auto loc = e.loc;

	ir.Exp outExp;
	final switch (pt.type) with (ir.PrimitiveType.Kind) {
	case Bool:
		outExp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name),
			[cast(ir.Exp)buildTernary(/*#ref*/loc, copyExp(e), buildConstantStringNoEscape(/*#ref*/loc, "true"),
			buildConstantStringNoEscape(/*#ref*/loc, "false"))]);
		break;
	case Char:
	case Wchar:
	case Dchar:
		lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/e.loc, "'"), sexp, sinkVar, dgt);
		outExp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.formatDchar, lp.formatDchar.name), [
			buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name), 
			buildCast(/*#ref*/loc, buildDchar(/*#ref*/loc), copyExp(e))]);
		lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/e.loc, "'"), sexp, sinkVar, dgt);
		break;
	case Ubyte:
	case Ushort:
	case Uint:
	case Ulong:
		outExp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.formatU64, lp.formatU64.name), [
			buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name), 
			buildCast(/*#ref*/loc, buildUlong(/*#ref*/loc), copyExp(e))]);
		break;
	case Byte:
	case Short:
	case Int:
	case Long:
		outExp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.formatI64, lp.formatI64.name), [
			buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name), 
			buildCast(/*#ref*/loc, buildLong(/*#ref*/loc), copyExp(e))]);
		break;
	case Float:
		outExp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.formatF32, lp.formatF32.name), [
			buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name), 
			copyExp(e), buildConstantInt(/*#ref*/loc, -1)]);
		break;
	case Double:
		outExp = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.formatF64, lp.formatF64.name), [
			buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name), 
			copyExp(e), buildConstantInt(/*#ref*/loc, -1)]);
		break;
	case Real:
		assert(false);
	case ir.PrimitiveType.Kind.Invalid:
	case Void:
		assert(false);
	}

	dgt(outExp);
}

//! Lower an associative array component of a composable string.
void lowerComposableStringAAComponent(LanguagePass lp, ir.Scope current, ir.Exp e,
	ir.AAType aatype, ir.StatementExp sexp, ir.Variable sinkVar, NodeConsumer dgt,
	LlvmLowerer lowerer)
{
	ir.Exp keys()
	{
		auto _keys = buildAAKeys(/*#ref*/e.loc, aatype, [copyExp(e)]);
		ir.Exp kexp = _keys;
		lowerBuiltin(lp, current, /*#ref*/kexp, _keys, lowerer);
		return kexp;
	}

	ir.Exp values()
	{
		auto _values = buildAAValues(/*#ref*/e.loc, aatype, [copyExp(e)]);
		ir.Exp vexp = _values;
		lowerBuiltin(lp, current,/*#ref*/ vexp, _values, lowerer);
		return vexp;
	}

	ir.Exp length()
	{
		auto _length = buildAALength(/*#ref*/e.loc, lp.target, [copyExp(e)]);
		ir.Exp lexp = _length;
		lowerBuiltin(lp, current, /*#ref*/lexp, _length, lowerer);
		return lexp;
	}

	auto loc = e.loc;
	lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, "["), sexp, sinkVar, dgt);
	ir.ForStatement fs;
	ir.Variable ivar;
	buildForStatement(/*#ref*/e.loc, lp.target, current, length(), /*#out*/fs, /*#out*/ivar);
	void addToForStatement(ir.Node n)
	{
		auto exp = cast(ir.Exp)n;
		if (exp !is null) {
			n = buildExpStat(/*#ref*/e.loc, exp);
		}
		fs.block.statements ~= n;
	}
	ir.Node gottenNode;
	void getNode(ir.Node n)
	{
		gottenNode = n;
	}
	version (D_Version2) {
		auto forDgt = &addToForStatement;
		auto getDgt = &getNode;
	} else {
		auto forDgt = addToForStatement;
		auto getDgt = getNode;
	}

	lowerComposableStringComponent(lp, current, buildIndex(/*#ref*/e.loc, keys(),
		buildExpReference(/*#ref*/ivar.loc, ivar, ivar.name)),
		sexp, sinkVar, forDgt, lowerer);
	lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, ":"), sexp, sinkVar, forDgt);
	lowerComposableStringComponent(lp, current, buildIndex(/*#ref*/e.loc, values(),
		buildExpReference(/*#ref*/ivar.loc, ivar, ivar.name)),
		sexp, sinkVar, forDgt, lowerer);

	auto lengthSub1 = buildSub(/*#ref*/loc, length(), buildConstantSizeT(/*#ref*/loc, lp.target, 1));
	auto cmp = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Less, buildExpReference(/*#ref*/loc, ivar, ivar.name), lengthSub1);

	lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, ", "), sexp, sinkVar, getDgt);
	auto bs = buildBlockStat(/*#ref*/loc, null, fs.block.myScope, buildExpStat(/*#ref*/e.loc, cast(ir.Exp)gottenNode));
	auto ifs = buildIfStat(/*#ref*/loc, cmp, bs);
	forDgt(ifs);

	dgt(fs);
	lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, "]"), sexp, sinkVar, dgt);
}

//! Lower an array component of a composable string.
void lowerComposableStringArrayComponent(LanguagePass lp, ir.Scope current, ir.Exp e,
	ir.StatementExp sexp, ir.Variable sinkVar, NodeConsumer dgt, LlvmLowerer lowerer)
{
	auto loc = e.loc;
	lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, "["), sexp, sinkVar, dgt);

	ir.Variable arrayVariable;
	auto type = getExpType(e);
	arrayVariable = buildVariable(/*#ref*/loc, copyType(type), ir.Variable.Storage.Function, current.genAnonIdent(), copyExp(e));
	arrayVariable.mangledName = arrayVariable.type.mangledName = mangle(type);
	dgt(arrayVariable);
	ir.ExpReference aref()
	{
		return buildExpReference(/*#ref*/loc, arrayVariable, arrayVariable.name);
	}

	ir.ForStatement fs;
	ir.Variable ivar;
	buildForStatement(/*#ref*/e.loc, lp.target, current, buildArrayLength(/*#ref*/loc, lp.target, aref()), /*#out*/fs, /*#out*/ivar);
	void addToForStatement(ir.Node n)
	{
		auto exp = cast(ir.Exp)n;
		if (exp !is null) {
			n = buildExpStat(/*#ref*/e.loc, exp);
		}
		fs.block.statements ~= n;
	}
	ir.Node gottenNode;
	void getNode(ir.Node n)
	{
		gottenNode = n;
	}
	version (D_Version2) {
		auto forDgt = &addToForStatement;
		auto getDgt = &getNode;
	} else {
		auto forDgt = addToForStatement;
		auto getDgt = getNode;
	}
	lowerComposableStringComponent(lp, current, buildIndex(/*#ref*/e.loc, aref(),
		buildExpReference(/*#ref*/ivar.loc, ivar, ivar.name)),
		sexp, sinkVar, forDgt, lowerer);

	auto lengthSub1 = buildSub(/*#ref*/loc, buildArrayLength(/*#ref*/loc, lp.target, aref()), buildConstantSizeT(/*#ref*/loc, lp.target, 1));
	auto cmp = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Less, buildExpReference(/*#ref*/loc, ivar, ivar.name), lengthSub1);

	lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, ", "), sexp, sinkVar, getDgt);
	auto bs = buildBlockStat(/*#ref*/loc, null, fs.block.myScope, buildExpStat(/*#ref*/e.loc, cast(ir.Exp)gottenNode));
	auto ifs = buildIfStat(/*#ref*/loc, cmp, bs);
	forDgt(ifs);

	dgt(fs);
	lowerComposableStringStringComponent(buildConstantStringNoEscape(/*#ref*/loc, "]"), sexp, sinkVar, dgt);
}

//! Lower a pointer component of a composable string.
void lowerComposableStringPointerComponent(LanguagePass lp, ir.Exp e, ir.StatementExp sexp, ir.Variable sinkVar,
	NodeConsumer dgt)
{
	auto loc = e.loc;
	auto call = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, lp.formatHex, lp.formatHex.name), [
		buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name),
		buildCast(/*#ref*/loc, buildUlong(/*#ref*/loc), copyExp(e)),
		buildConstantSizeT(/*#ref*/loc, lp.target, lp.target.isP64 ? 16 : 8)]);
	dgt(call);
}

//! Lower an enum component of a composable string.
void lowerComposableStringEnumComponent(LanguagePass lp, ir.Scope current, ir.Enum _enum, ir.Exp e,
	ir.StatementExp sexp, ir.Variable sinkVar, NodeConsumer dgt)
{
	if (_enum.toSink is null) {
		_enum.toSink = generateToSink(/*#ref*/e.loc, lp, current, _enum);
	}
	auto loc = e.loc;
	auto call = buildCall(/*#ref*/loc, buildExpReference(/*#ref*/loc, _enum.toSink, _enum.toSink.name), [
		copyExp(e), buildExpReference(/*#ref*/loc, sinkVar, sinkVar.name)]);
	dgt(call);
}

/*!
 * Generate the function that fills in the `toSink` field on an `Enum`.
 *
 * Used by the composable string code to turn `"${SomeEnum.Member}"` into `"Member"`.
 */
ir.Function generateToSink(ref in Location loc, LanguagePass lp, ir.Scope current, ir.Enum _enum)
{
	/* ```volt
	 * fn toSink(e: EnumName, sink: Sink) {
     *     // This switch is generated by a builtin in the backend.
	 *     switch (e) {
	 *     case EnumName.MemberZero: sink("MemberZero"); break;
	 *     default: assert(false);
	 *     }
	 * }
	 * ```
	 */
	auto mod = getModuleFromScope(/*#ref*/loc, current);
	auto ftype = buildFunctionTypeSmart(/*#ref*/loc, buildVoid(/*#ref*/loc));
	auto func = buildFunction(lp.errSink, /*#ref*/loc, mod.children, mod.myScope, "__toSink" ~ _enum.mangledName);
	auto enumParam = addParamSmart(lp.errSink, /*#ref*/loc, func, _enum, "e");
	auto sinkParam = addParamSmart(lp.errSink, /*#ref*/loc, func, lp.sinkType, "sink");

	auto em = buildEnumMembers(/*#ref*/loc, _enum,
		buildExpReference(/*#ref*/loc, enumParam, enumParam.name), buildExpReference(/*#ref*/loc, sinkParam, sinkParam.name));
	em.functions ~= lp.ehThrowAssertErrorFunc;
	func._body.statements ~= buildExpStat(/*#ref*/loc, em);
	buildReturnStat(/*#ref*/loc, func._body);
	return func;
}

//! Lower a string component of a composable string.
void lowerComposableStringStringComponent(ir.Exp e, ir.StatementExp sexp, ir.Variable sinkVar)
{
	auto l = e.loc;
	auto call = buildCall(/*#ref*/l, buildExpReference(/*#ref*/l, sinkVar, sinkVar.name), [copyExp(e)]);
	buildExpStat(/*#ref*/l, sexp, call);
}

//! Lower a string component of a composable string.
void lowerComposableStringStringComponent(ir.Exp e, ir.StatementExp sexp, ir.Variable sinkVar,
	NodeConsumer dgt)
{
	auto l = e.loc;
	auto call = buildCall(/*#ref*/l, buildExpReference(/*#ref*/l, sinkVar, sinkVar.name), [copyExp(e)]);
	dgt(call);
}

//! Build an if statement based on a runtime assert.
ir.IfStatement lowerAssertIf(LanguagePass lp, ir.Scope current, ir.AssertStatement as)
{
	panicAssert(as, !as.isStatic);
	auto loc = as.loc;
	ir.Exp message = as.message;
	if (message is null) {
		message = buildConstantStringNoEscape(/*#ref*/loc, "assertion failure");
	}
	assert(message !is null);
	ir.Exp locstr = buildConstantStringNoEscape(/*#ref*/loc, format("%s:%s", as.loc.filename, as.loc.line));
	auto theThrow = buildExpStat(/*#ref*/loc, buildCall(/*#ref*/loc, lp.ehThrowAssertErrorFunc, [locstr, message]));
	auto thenBlock = buildBlockStat(/*#ref*/loc, null, current, theThrow);
	auto ifS = buildIfStat(/*#ref*/loc, buildNot(/*#ref*/loc, as.condition), thenBlock);
	return ifS;
}

/*!
 * Given a throw statement, turn its expression into a call into the RT.
 *
 * Params:
 *   lp: The LanguagePass.
 *   t: The ThrowStatement to lower.
 */
void lowerThrow(LanguagePass lp, ir.ThrowStatement t)
{
	t.exp = buildCall(/*#ref*/t.loc, lp.ehThrowFunc, [t.exp,
	                  buildConstantStringNoEscape(/*#ref*/t.loc, format("%s:%s", t.loc.filename, t.loc.line))]);
}

/*!
 * Replace a StringImport with the string in the file it points at, or error.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The scope at where the StringImport is.
 *   exp: The expression to write the new string into.
 *   simport: The StringImport to lower.
 */
void lowerStringImport(Driver driver, ref ir.Exp exp, ir.StringImport simport)
{
	auto constant = cast(ir.Constant)simport.filename;
	panicAssert(simport, constant !is null);

	// Remove string literal terminators.
	auto fname = constant._string[1 .. $-1];

	// Ask the driver for the file contents.
	auto str = driver.stringImport(/*#ref*/exp.loc, fname);

	// Build and replace.
	exp = buildConstantStringNoEscape(/*#ref*/exp.loc, str);
}

/*!
 * Turn `Struct a = {1, "banana"};`
 * into `Struct a; a.firstField = 1; b.secondField = "banana";`.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The scope where the StructLiteral occurs.
 *   exp: The expression of the StructLiteral.
 *   literal: The StructLiteral to lower.
 */
void lowerStructLiteral(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.StructLiteral literal)
{
	// Pull out the struct and its fields.
	panicAssert(exp, literal.type !is null);
	auto theStruct = cast(ir.Struct) realType(literal.type);
	panicAssert(exp, theStruct !is null);
	auto fields = getStructFieldVars(theStruct);
	// The extyper should've caught this.
	panicAssert(exp, fields.length >= literal.exps.length);

	// Struct __anon;
	auto loc = exp.loc;
	auto sexp = buildStatementExp(/*#ref*/loc);
	auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, theStruct, null);

	// Assign the literal expressions to the fields.
	foreach (i, e; literal.exps) {
		auto eref = buildExpReference(/*#ref*/loc, var, var.name);
		auto lh = buildAccessExp(/*#ref*/loc, eref, fields[i]);
		auto assign = buildAssign(/*#ref*/loc, lh, e);
		buildExpStat(/*#ref*/loc, sexp, assign);
	}

	sexp.exp = buildExpReference(/*#ref*/loc, var, var.name);
	sexp.originalExp = exp;
	exp = sexp;
}

/*!
 * Lower a postfix index expression.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   postfix: The postfix expression to potentially lower.
 */
void lowerIndex(LanguagePass lp, ir.Scope current, ir.Module thisModule,
                ref ir.Exp exp, ir.Postfix postfix, LlvmLowerer lowerer)
{
	auto type = getExpType(postfix.child);
	if (type.nodeType == ir.NodeType.AAType) {
		lowerIndexAA(lp, current, thisModule, /*#ref*/exp, postfix, cast(ir.AAType)type, lowerer);
	}
	// LLVM appears to have some issues with small indices.
	// If this is being indexed by a small type, cast it up.
	if (postfix.arguments.length > 0) {
		panicAssert(exp, postfix.arguments.length == 1);
		auto prim = cast(ir.PrimitiveType)realType(getExpType(postfix.arguments[0]));
		if (prim !is null && size(lp.target, prim) < 4/*Smaller than a 32 bit integer.*/) {
			auto loc = postfix.arguments[0].loc;
			postfix.arguments[0] = buildCastSmart(buildInt(/*#ref*/loc), postfix.arguments[0]);
		}
	}
}

/*!
 * Lower a postfix index expression that operates on an AA.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   postfix: The postfix expression to potentially lower.
 *   aa: The type of the AA being operated on.
 */
void lowerIndexAA(LanguagePass lp, ir.Scope current, ir.Module thisModule,
                  ref ir.Exp exp, ir.Postfix postfix, ir.AAType aa, LlvmLowerer lowerer)
{
	auto loc = postfix.loc;
	auto statExp = buildStatementExp(/*#ref*/loc);

	auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, cast(ir.BlockStatement)current.node, statExp,
		buildPtrSmart(/*#ref*/loc, aa), buildAddrOf(/*#ref*/loc, postfix.child)
	);

	auto key = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, cast(ir.BlockStatement)current.node, statExp,
		copyTypeSmart(/*#ref*/loc, aa.key), postfix.arguments[0]
	);
	auto store = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, cast(ir.BlockStatement)current.node, statExp,
		copyTypeSmart(/*#ref*/loc, aa.value), null
	);

	lowerAALookup(/*#ref*/loc, lp, thisModule, current, statExp, aa, var,
		buildExpReference(/*#ref*/loc, key, key.name),
		buildExpReference(/*#ref*/loc, store, store.name),
		lowerer
	);

	statExp.exp = buildExpReference(/*#ref*/loc, store);

	exp = statExp;
}

/*!
 * Lower an assign if it needs it.
 *
 * Params:
 *   lp: The LanguagePass.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   binOp: The BinOp with the assign to potentially lower.
 */
void lowerAssign(LanguagePass lp, ir.Module thisModule, ref ir.Exp exp, ir.BinOp binOp)
{
	auto asPostfix = cast(ir.Postfix)binOp.left;
	if (asPostfix is null) {
		return;
	}

	auto leftType = getExpType(asPostfix);
	if (leftType is null || leftType.nodeType != ir.NodeType.ArrayType) {
		return;
	}

	lowerAssignArray(lp, thisModule, /*#ref*/exp, binOp, asPostfix, cast(ir.ArrayType)leftType);
}

/*!
 * Lower an assign to an array if it's being modified by a postfix.
 *
 * Params:
 *   lp: The LanguagePass.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   binOp: The BinOp with the assign to potentially lower.
 *   asPostfix: The postfix operation modifying the array.
 *   leftType: The array type of the left hand side of the assign.
 */
void lowerAssignArray(LanguagePass lp, ir.Module thisModule, ref ir.Exp exp,
                      ir.BinOp binOp, ir.Postfix asPostfix, ir.ArrayType leftType)
{
	auto loc = binOp.loc;

	if (asPostfix.op != ir.Postfix.Op.Slice) {
		return;
	}

	auto func = getArrayCopyFunction(/*#ref*/loc, lp, thisModule, leftType);
	exp = buildCall(/*#ref*/loc, func, [asPostfix, binOp.right], func.name);
}

/*!
 * Lower an assign to an AA.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   binOp: The BinOp with the assign to potentially lower.
 *   asPostfix: The left hand side of the assign as a postfix.
 *   aa: The AA type that the expression is assigning to.
 */
void lowerAssignAA(LanguagePass lp, ir.Scope current, ir.Module thisModule,
                   ref ir.Exp exp, ir.BinOp binOp, ir.Postfix asPostfix, ir.AAType aa,
				   LlvmLowerer lowerer)
{
	auto loc = binOp.loc;
	assert(asPostfix.op == ir.Postfix.Op.Index);
	auto statExp = buildStatementExp(/*#ref*/loc);

	auto bs = cast(ir.BlockStatement)current.node;
	if (bs is null) {
		auto func = cast(ir.Function)current.node;
		if (func !is null) {
			bs = func._body;
		}
	}
	panicAssert(exp, bs !is null);

	auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, bs, statExp,
		buildPtrSmart(/*#ref*/loc, aa), buildAddrOf(/*#ref*/loc, asPostfix.child)
	);

	auto key = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, bs, statExp,
		copyTypeSmart(/*#ref*/loc, aa.key), asPostfix.arguments[0]
	);
	auto value = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, bs, statExp,
		copyTypeSmart(/*#ref*/loc, aa.value), binOp.right
	);

	lowerAAInsert(/*#ref*/loc, lp, thisModule, current, statExp, aa, var,
			buildExpReference(/*#ref*/loc, key, key.name),
			buildExpReference(/*#ref*/loc, value, value.name),
			lowerer
	);

	statExp.exp = buildExpReference(/*#ref*/loc, value, value.name);
	exp = statExp;
}

/*!
 * Lower a +=, *=, etc assign to an AA.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   binOp: The BinOp with the assign to potentially lower.
 *   asPostfix: The left hand side of the assign as a postfix.
 *   aa: The AA type that the expression is assigning to.
 */
void lowerOpAssignAA(LanguagePass lp, ir.Scope current, ir.Module thisModule,
                     ref ir.Exp exp, ir.BinOp binOp, ir.Postfix asPostfix, ir.AAType aa,
					 LlvmLowerer lowerer)
{
	auto loc = binOp.loc;
	assert(asPostfix.op == ir.Postfix.Op.Index);
	auto statExp = buildStatementExp(/*#ref*/loc);

	auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, cast(ir.BlockStatement)current.node, statExp,
		buildPtrSmart(/*#ref*/loc, aa), null
	);
	buildExpStat(/*#ref*/loc, statExp,
		buildAssign(/*#ref*/loc, var, buildAddrOf(/*#ref*/loc, asPostfix.child))
	);

	auto key = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, cast(ir.BlockStatement)current.node, statExp,
		copyTypeSmart(/*#ref*/loc, aa.key), null
	);
	buildExpStat(/*#ref*/loc, statExp,
		buildAssign(/*#ref*/loc, key, asPostfix.arguments[0])
	);
	auto store = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, cast(ir.BlockStatement)current.node, statExp,
		copyTypeSmart(/*#ref*/loc, aa.value), null
	);

	lowerAALookup(/*#ref*/loc, lp, thisModule, current, statExp, aa, var,
		buildExpReference(/*#ref*/loc, key, key.name),
		buildExpReference(/*#ref*/loc, store, store.name),
		lowerer
	);

	buildExpStat(/*#ref*/loc, statExp,
		buildBinOp(/*#ref*/loc, binOp.op,
			buildExpReference(/*#ref*/loc, store, store.name),
			binOp.right
		)
	);

	lowerAAInsert(/*#ref*/loc, lp, thisModule, current, statExp, aa, var,
		buildExpReference(/*#ref*/loc, key, key.name),
		buildExpReference(/*#ref*/loc, store, store.name),
		lowerer,
		false
	);

	statExp.exp = buildExpReference(/*#ref*/loc, store, store.name);
	exp = statExp;
}

/*!
 * Lower a concatenation operation. (A ~ B)
 *
 * Params:
 *   lp: The LanguagePass.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   binOp: The BinOp with the concatenation to lower.
 */
void lowerCat(LanguagePass lp, ir.Module thisModule, ref ir.Exp exp, ir.BinOp binOp)
{
	auto loc = binOp.loc;

	auto leftType = getExpType(binOp.left);
	auto rightType = getExpType(binOp.right);

	auto arrayType = cast(ir.ArrayType)leftType;
	auto elementType = rightType;
	bool reversed = false;
	if (arrayType is null) {
		reversed = true;
		arrayType = cast(ir.ArrayType) rightType;
		elementType = leftType;
		if (arrayType is null) {
			throw panic(/*#ref*/exp.loc, "array concat failure");
		}
	}

	if (typesEqual(realType(elementType, true), realType(arrayType.base, true))) {
		// T[] ~ T
		ir.Function func;
		if (reversed) {
			func = getArrayPrependFunction(/*#ref*/loc, lp, thisModule, arrayType, elementType);
		} else {
			func = getArrayAppendFunction(/*#ref*/loc, lp, thisModule, arrayType, elementType, false);
		}
		exp = buildCall(/*#ref*/loc, func, [binOp.left, binOp.right], func.name);
	} else {
		// T[] ~ T[]
		auto func = getArrayConcatFunction(/*#ref*/loc, lp, thisModule, arrayType, false);
		exp = buildCall(/*#ref*/loc, func, [binOp.left, binOp.right], func.name);
	}

	return;
}

/*!
 * Lower a concatenation assign operation. (A ~= B)
 *
 * Params:
 *   lp: The LanguagePass.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   binOp: The BinOp with the concatenation assign to lower.
 */
void lowerCatAssign(LanguagePass lp, ir.Module thisModule, ref ir.Exp exp, ir.BinOp binOp)
{
	auto loc = binOp.loc;

	auto leftType = getExpType(binOp.left);
	auto leftArrayType = cast(ir.ArrayType)realType(leftType);
	if (leftArrayType is null) {
		throw panic(binOp, "couldn't retrieve array type from cat assign.");
	}

	// Currently realType is not needed here, but if it ever was
	// needed remember to realType leftArrayType.base as well,
	// since realType will remove enum's as well.
	auto rightType = getExpType(binOp.right);

	if (typesEqual(realType(rightType, true), realType(leftArrayType.base, true))) {
		// T[] ~ T
		auto func = getArrayAppendFunction(/*#ref*/loc, lp, thisModule, leftArrayType, rightType, true);
		exp = buildCall(/*#ref*/loc, func, [buildAddrOf(binOp.left), binOp.right], func.name);
	} else {
		auto func = getArrayConcatFunction(/*#ref*/loc, lp, thisModule, leftArrayType, true);
		exp = buildCall(/*#ref*/loc, func, [buildAddrOf(binOp.left), binOp.right], func.name);
	}
}

/*!
 * Lower an equality operation, if it needs it.
 *
 * Params:
 *   lp: The LanguagePass.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   binOp: The BinOp with the equality operation to potentially lower.
 */
void lowerEqual(LanguagePass lp, ir.Module thisModule, ref ir.Exp exp, ir.BinOp binOp)
{
	auto loc = binOp.loc;

	auto leftType = getExpType(binOp.left);
	auto leftArrayType = cast(ir.ArrayType)leftType;
	if (leftArrayType is null) {
		return;
	}

	auto func = getArrayCmpFunction(/*#ref*/loc, lp, thisModule, leftArrayType, binOp.op == ir.BinOp.Op.NotEqual);
	exp = buildCall(/*#ref*/loc, func, [binOp.left, binOp.right], func.name);
}

/*!
 * Lower an expression that casts to an interface.
 *
 * Params:
 *   loc: Nodes created in this function will be given this loc.
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   uexp: The interface cast to lower.
 *   exp: A reference to the relevant expression.
 */
void lowerInterfaceCast(ref in Location loc, LanguagePass lp,
                        ir.Scope current, ir.Unary uexp, ref ir.Exp exp)
{
	if (uexp.op != ir.Unary.Op.Cast) {
		return;
	}
	auto iface = cast(ir._Interface) realType(uexp.type);
	if (iface is null) {
		return;
	}
	auto agg = cast(ir.Aggregate) realType(getExpType(uexp.value));
	if (agg is null) {
		return;
	}
	auto store = lookupInGivenScopeOnly(lp, agg.myScope, /*#ref*/loc, mangle(iface));
	panicAssert(uexp, store !is null);
	auto var = cast(ir.Variable)store.node;
	panicAssert(uexp, var !is null);
	exp = buildAddrOf(/*#ref*/loc, buildAccessExp(/*#ref*/loc, uexp.value, var));
}

/*!
 * Lower an expression that casts to an array.
 *
 * Params:
 *   loc: Nodes created in this function will be given this loc.
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   uexp: The array cast to lower.
 *   exp: A reference to the relevant expression.
 */
void lowerArrayCast(ref in Location loc, LanguagePass lp, ir.Scope current,
                    ir.Unary uexp, ref ir.Exp exp)
{
	if (uexp.op != ir.Unary.Op.Cast) {
		return;
	}

	auto toArray = cast(ir.ArrayType) realType(uexp.type);
	if (toArray is null) {
		return;
	}
	auto fromArray = cast(ir.ArrayType) getExpType(uexp.value);
	if (fromArray is null) {
		auto stype = cast(ir.StaticArrayType) getExpType(uexp.value);
		if (stype !is null) {
			uexp.value = buildSlice(/*#ref*/exp.loc, uexp.value);
			fromArray = cast(ir.ArrayType)getExpType(uexp.value);
			panicAssert(exp, fromArray !is null);
		} else {
			return;
		}
	}
	if (typesEqual(toArray, fromArray)) {
		return;
	}

	auto toClass = cast(ir.Class) realType(toArray.base);
	auto fromClass = cast(ir.Class) realType(fromArray.base);
	if (toClass !is null && fromClass !is null && isOrInheritsFrom(fromClass, toClass)) {
		return;
	}

	auto fromSz = size(lp.target, fromArray.base);
	auto toSz = size(lp.target, toArray.base);
	auto biggestSz = fromSz > toSz ? fromSz : toSz;
	bool decreasing = fromSz > toSz;

	// Skip lowering if the same size, the backend can handle it.
	if (fromSz == toSz) {
		return;
	}

	// ({
	auto sexp = new ir.StatementExp();
	sexp.loc = loc;

	// auto arr = <exp>
	auto varName = "arr";
	auto var = buildVariableSmart(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, fromArray), ir.Variable.Storage.Function, varName);
	var.assign = uexp.value;
	sexp.statements ~= var;

	if (fromSz % toSz) {
		//     vrt_throw_slice_error(arr.length, typeid(T).size);
		auto ln = buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, var, varName));
		auto sz = getSizeOf(/*#ref*/loc, lp, toArray.base);
		ir.Exp locstr = buildConstantStringNoEscape(/*#ref*/loc, format("%s:%s", exp.loc.filename, exp.loc.line));
		auto rtCall = buildCall(/*#ref*/loc, lp.ehThrowSliceErrorFunc, [locstr]);
		auto bs = buildBlockStat(/*#ref*/loc, rtCall, current, buildExpStat(/*#ref*/loc, rtCall));
		auto check = buildBinOp(/*#ref*/loc, ir.BinOp.Op.NotEqual,
		                        buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mod, ln, sz),
		                        buildConstantSizeT(/*#ref*/loc, lp.target, 0));
		auto _if = buildIfStat(/*#ref*/loc, check, bs);
		sexp.statements ~= _if;
	}

	auto inLength = buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, var, varName));
	ir.Exp lengthTweak;
	if (fromSz == toSz) {
		lengthTweak = inLength;
	} else if (!decreasing) {
		lengthTweak = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Div, inLength,
		                         buildConstantSizeT(/*#ref*/loc, lp.target, biggestSz));
	} else {
		lengthTweak = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Mul, inLength,
		                         buildConstantSizeT(/*#ref*/loc, lp.target, biggestSz));
	}

	auto ptrType = buildPtrSmart(/*#ref*/loc, toArray.base);
	auto ptrIn = buildArrayPtr(/*#ref*/loc, fromArray.base, buildExpReference(/*#ref*/loc, var, varName));
	auto ptrOut = buildCast(/*#ref*/loc, ptrType, ptrIn);
	sexp.exp = buildSlice(/*#ref*/loc, ptrOut, buildConstantSizeT(/*#ref*/loc, lp.target, 0), lengthTweak);
	exp = sexp;
}

/*!
 * Is a given postfix an interface pointer? If so, which one?
 *
 * Params:
 *   lp: The LanguagePass.
 *   pfix: The Postfix to check.
 *   current: The scope where the postfix resides.
 *   iface: Will be filled in with the Interface if the postfix is a pointer to one.
 *
 * Returns: true if pfix's type is an interface pointer, false otherwise.
 */
bool isInterfacePointer(LanguagePass lp, ir.Postfix pfix, ir.Scope current, out ir._Interface iface)
{
	pfix = cast(ir.Postfix) pfix.child;
	if (pfix is null) {
		return false;
	}
	auto t = getExpType(pfix.child);
	iface = cast(ir._Interface) realType(t);
	if (iface !is null) {
		return true;
	}
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

/*!
 * If a postfix operates directly on a struct via a
 * function call, put it in a variable first.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   exp: A reference to the relevant expression.
 *   ae: The AccessExp to check.
 */
void lowerStructLookupViaFunctionCall(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.AccessExp ae, ir.Type type)
{
	auto loc = ae.loc;
	auto statExp = buildStatementExp(/*#ref*/loc);
	auto host = getParentFunction(current);
	auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, host._body, statExp, type,
	                                  ae.child);
	ae.child = buildExpReference(/*#ref*/loc, var, var.name);
	statExp.exp = exp;
	exp = statExp;
}

/*!
 * Rewrites a given foreach statement (fes) into a for statement.
 *
 * The ForStatement created uses several of the fes's nodes directly; that is
 * to say, the original foreach and the new for cannot coexist.
 *
 * Params:
 *   fes: The ForeachStatement to lower.
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *
 * Returns: The lowered ForStatement.
 */
ir.ForStatement lowerForeach(ir.ForeachStatement fes, LanguagePass lp,
                             ir.Scope current)
{
	auto loc = fes.loc;
	auto fs = new ir.ForStatement();
	fs.loc = loc;
	panicAssert(fes, fes.itervars.length == 1 || fes.itervars.length == 2);
	fs.initVars = fes.itervars;
	fs.block = fes.block;

	// foreach (i; 5 .. 7) => for (int i = 5; i < 7; i++)
	// foreach_reverse (i; 5 .. 7) => for (int i = 7 - 1; i >= 5; i--)
	if (fes.beginIntegerRange !is null) {
		panicAssert(fes, fes.endIntegerRange !is null);
		panicAssert(fes, fes.itervars.length == 1);
		auto v = fs.initVars[0];
		auto begin = realType(getExpType(fes.beginIntegerRange));
		auto end = realType(getExpType(fes.endIntegerRange));
		if (!isIntegral(begin) || !isIntegral(end)) {
			throw makeExpected(/*#ref*/fes.beginIntegerRange.loc,
			                   "integral beginning and end of range");
		}
		panicAssert(fes, typesEqual(begin, end));
		if (v.type is null) {
			v.type = copyType(begin);
		}
		v.assign = fes.reverse ?
		           buildSub(/*#ref*/loc, fes.endIntegerRange, buildConstantInt(/*#ref*/loc, 1)) :
		           fes.beginIntegerRange;

		auto cmpRef = buildExpReference(/*#ref*/v.loc, v, v.name);
		auto incRef = buildExpReference(/*#ref*/v.loc, v, v.name);
		fs.test = buildBinOp(/*#ref*/loc,
		                     fes.reverse ? ir.BinOp.Op.GreaterEqual : ir.BinOp.Op.Less,
		                     cmpRef,
		                     buildCastSmart(/*#ref*/loc, begin,
		                     fes.reverse ? fes.beginIntegerRange : fes.endIntegerRange));
		fs.increments ~= fes.reverse ? buildDecrement(/*#ref*/v.loc, incRef) :
		                 buildIncrement(/*#ref*/v.loc, incRef);
		return fs;
	}


	// foreach (e; a) => foreach (e; auto _anon = a)
	auto sexp = buildStatementExp(/*#ref*/loc);

	// foreach (i, e; array) => for (size_t i = 0; i < array.length; i++) auto e = array[i]; ...
	// foreach_reverse (i, e; array) => for (size_t i = array.length - 1; i+1 >= 0; i--) auto e = array[i]; ..
	auto aggType = realType(getExpType(fes.aggregate));

	if (aggType.nodeType == ir.NodeType.ArrayType ||
	    aggType.nodeType == ir.NodeType.StaticArrayType) {
	    //
		aggType = realType(getExpType(buildSlice(/*#ref*/loc, fes.aggregate)));
		auto anonVar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, aggType,
		                                      buildSlice(/*#ref*/loc, fes.aggregate));
		anonVar.type.mangledName = mangle(aggType);
		scope (exit) fs.initVars = anonVar ~ fs.initVars;
		ir.ExpReference aggref() { return buildExpReference(/*#ref*/loc, anonVar, anonVar.name); }
		fes.aggregate = aggref();

		// i = 0 / i = array.length
		ir.Variable indexVar, elementVar;
		ir.Exp indexAssign;
		if (!fes.reverse) {
			indexAssign = buildConstantSizeT(/*#ref*/loc, lp.target, 0);
		} else {
			indexAssign = buildArrayLength(/*#ref*/loc, lp.target, aggref());
		}
		if (fs.initVars.length == 2) {
			indexVar = fs.initVars[0];
			if (indexVar.type is null) {
				indexVar.type = buildSizeT(/*#ref*/loc, lp.target);
			}
			indexVar.assign = indexAssign;
			elementVar = fs.initVars[1];
		} else {
			panicAssert(fes, fs.initVars.length == 1);
			indexVar = buildVariable(/*#ref*/loc, buildSizeT(/*#ref*/loc, lp.target),
			                         ir.Variable.Storage.Function, "i", indexAssign);
			elementVar = fs.initVars[0];
		}

		// Move element var to statements so it can be const/immutable.
		fs.initVars = [indexVar];
		fs.block.statements = [cast(ir.Node)elementVar] ~ fs.block.statements;

		ir.Variable nextIndexVar;  // This is what we pass when decoding strings.
		if (fes.decodeFunction !is null && !fes.reverse) {
			auto ivar = buildExpReference(/*#ref*/indexVar.loc, indexVar, indexVar.name);
			nextIndexVar = buildVariable(/*#ref*/loc, buildSizeT(/*#ref*/loc, lp.target),
			                             ir.Variable.Storage.Function, "__nexti", ivar);
			fs.initVars ~= nextIndexVar;
		}



		// i < array.length / i + 1 >= 0
		auto tref = buildExpReference(/*#ref*/indexVar.loc, indexVar, indexVar.name);
		auto rtref = buildDecrement(/*#ref*/loc, tref);
		auto length = buildArrayLength(/*#ref*/loc, lp.target, fes.aggregate);
		auto zero = buildConstantSizeT(/*#ref*/loc, lp.target, 0);
		fs.test = buildBinOp(/*#ref*/loc, fes.reverse ? ir.BinOp.Op.Greater : ir.BinOp.Op.Less,
							 fes.reverse ? rtref : tref,
							 fes.reverse ? zero : length);

		// auto e = array[i]; i++/i--
		auto incRef = buildExpReference(/*#ref*/indexVar.loc, indexVar, indexVar.name);
		auto accessRef = buildExpReference(/*#ref*/indexVar.loc, indexVar, indexVar.name);
		auto eRef = buildExpReference(/*#ref*/elementVar.loc, elementVar, elementVar.name);
		if (fes.decodeFunction !is null) {  // foreach (i, dchar c; str)
			auto dfn = buildExpReference(/*#ref*/loc, fes.decodeFunction, fes.decodeFunction.name);
			if (!fes.reverse) {
				elementVar.assign = buildCall(/*#ref*/loc, dfn,
				    [cast(ir.Exp)aggref(), cast(ir.Exp)buildExpReference(/*#ref*/loc, nextIndexVar,
				    nextIndexVar.name)]);
				fs.increments ~= buildAssign(/*#ref*/loc, indexVar, nextIndexVar);
			} else {
				elementVar.assign = buildCall(/*#ref*/loc, dfn, [cast(ir.Exp)aggref(),
				    cast(ir.Exp)buildExpReference(/*#ref*/indexVar.loc, indexVar, indexVar.name)]);
			}
		} else {
			elementVar.assign = buildIndex(/*#ref*/incRef.loc, aggref(), accessRef);
			if (!fes.reverse) {
				fs.increments ~= buildIncrement(/*#ref*/incRef.loc, incRef);
			}
		}



		foreach (i, ivar; fes.itervars) {
			if (!fes.refvars[i]) {
				continue;
			}
			if (i == 0 && fes.itervars.length > 1) {
				throw makeForeachIndexRef(/*#ref*/fes.loc);
			}
			auto nr = new ExpReferenceReplacer(ivar, elementVar.assign);
			accept(fs.block, nr);
		}

		return fs;
	}

	// foreach (k, v; aa) => for (size_t i; i < aa.keys.length; i++) k = aa.keys[i]; v = aa[k];
	// foreach_reverse => error, as order is undefined.
	auto aaanonVar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, aggType, fes.aggregate);
	aaanonVar.type.mangledName = mangle(aggType);
	scope (exit) fs.initVars = aaanonVar ~ fs.initVars;
	ir.ExpReference aaaggref() { return buildExpReference(/*#ref*/loc, aaanonVar, aaanonVar.name); }
	fes.aggregate = aaaggref();
	auto aa = cast(ir.AAType) aggType;
	if (aa !is null) {
		ir.Exp buildAACall(ir.Function func, ir.Type outType)
		{
			auto eref = buildExpReference(/*#ref*/loc, func, func.name);
			return buildCastSmart(/*#ref*/loc, outType, buildCall(/*#ref*/loc, eref,
			       [cast(ir.Exp)buildCastToVoidPtr(/*#ref*/loc, aaaggref())]));
		}

		if (fes.reverse) {
			throw makeForeachReverseOverAA(fes);
		}
		if (fs.initVars.length != 1 && fs.initVars.length != 2) {
			throw makeExpected(/*#ref*/fes.loc, "1 or 2 iteration variables");
		}

		auto valVar = fs.initVars[0];
		ir.Variable keyVar;
		if (fs.initVars.length == 2) {
			keyVar = valVar;
			valVar = fs.initVars[1];
		} else {
			keyVar = buildVariable(/*#ref*/loc, null, ir.Variable.Storage.Function,
			                       format("%sk", fs.block.myScope.nestedDepth));
			fs.initVars ~= keyVar;
		}

		auto vstor = cast(ir.StorageType) valVar.type;
		if (vstor !is null && vstor.type == ir.StorageType.Kind.Auto) {
			valVar.type = null;
		}

		auto kstor = cast(ir.StorageType) keyVar.type;
		if (kstor !is null && kstor.type == ir.StorageType.Kind.Auto) {
			keyVar.type = null;
		}

		if (valVar.type is null) {
			valVar.type = copyTypeSmart(/*#ref*/loc, aa.value);
		}
		if (keyVar.type is null) {
			keyVar.type = copyTypeSmart(/*#ref*/loc, aa.key);
		}
		auto indexVar = buildVariable(
			/*#ref*/loc,
			buildSizeT(/*#ref*/loc, lp.target),
			ir.Variable.Storage.Function,
			format("%si", fs.block.myScope.nestedDepth),
			buildConstantSizeT(/*#ref*/loc, lp.target, 0)
		);
		assert(keyVar.type !is null);
		assert(valVar.type !is null);
		assert(indexVar.type !is null);
		fs.initVars ~= indexVar;

		// Cached keys array
		auto keysArrayVar = buildVariable(
			/*#ref*/loc,
			buildArrayTypeSmart(/*#ref*/loc, keyVar.type),
			ir.Variable.Storage.Function,
			format("%skeysarr", fs.block.myScope.nestedDepth),
			buildAACall(lp.aaGetKeys, buildArrayTypeSmart(/*#ref*/loc, keyVar.type))
		);
		fs.initVars ~= keysArrayVar;

		// i < keysarr.length
		auto index = buildExpReference(/*#ref*/loc, indexVar, indexVar.name);
		auto len = buildArrayLength(/*#ref*/loc, lp.target,
			buildExpReference(/*#ref*/loc, keysArrayVar, keysArrayVar.name));
		fs.test = buildBinOp(/*#ref*/loc, ir.BinOp.Op.Less, index, len);

		// v = aa[k]
		auto rh2  = buildIndex(/*#ref*/loc, aaaggref(), buildExpReference(/*#ref*/loc, keyVar, keyVar.name));
		fs.block.statements = buildExpStat(/*#ref*/loc, buildAssign(/*#ref*/loc, valVar, rh2)) ~ fs.block.statements;

		// k = keysarr[i]
		auto keys = buildExpReference(/*#ref*/loc, keysArrayVar, keysArrayVar.name);
		auto rh   = buildIndex(/*#ref*/loc, keys, buildExpReference(/*#ref*/loc, indexVar, indexVar.name));
		fs.block.statements = buildExpStat(/*#ref*/loc, buildAssign(/*#ref*/loc, keyVar, rh)) ~ fs.block.statements;

		// i++
		fs.increments ~= buildIncrement(/*#ref*/loc, buildExpReference(/*#ref*/loc, indexVar, indexVar.name));

		return fs;
	}

	throw panic(/*#ref*/loc, "expected foreach aggregate type");
}

/*!
 * Lower an array literal to an internal array literal.
 *
 * The backend will treat any ArrayLiteral as full of constants, so we can't
 * pass most of them through.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   inFunction: Is this ArrayLiteral in a function or not?
 *   exp: A reference to the relevant expression.
 *   al: The ArrayLiteral to lower.
 */
void lowerArrayLiteral(LanguagePass lp, ir.Scope current,
                       ref ir.Exp exp, ir.ArrayLiteral al)
{
	auto at = getExpType(al);
	if (at.nodeType == ir.NodeType.StaticArrayType) {
		return;
	}
	assert(at.nodeType == ir.NodeType.ArrayType);
	bool isScope = at.isScope;

	auto arr = at.toArrayTypeFast();
	bool isBaseConst = arr.base.isConst;

	bool isExpsBackend;
	foreach (alexp; al.exps) {
		isExpsBackend = isBackendConstant(alexp);
		if (!isExpsBackend) {
			break;
		}
	}

	if ((!isBaseConst || !isExpsBackend) && isScope) {
		auto sa = buildStaticArrayTypeSmart(/*#ref*/exp.loc, al.exps.length, arr.base);
		auto sexp = buildInternalStaticArrayLiteralSmart(lp.errSink, /*#ref*/exp.loc, sa, al.exps);
		exp = buildSlice(/*#ref*/exp.loc, sexp);
	} else if (!isScope || !isBaseConst || !isExpsBackend) {
		auto sexp = buildInternalArrayLiteralSmart(lp.errSink, /*#ref*/al.loc, at, al.exps);
		sexp.originalExp = al;
		exp = sexp;
	}
}

/*!
 * Lower a builtin expression.
 *
 * These are comprised mostly of things that need calls to the RT to deal with them.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   exp: A reference to the relevant expression.
 *   builtin: The BuiltinExp to lower.
 */
void lowerBuiltin(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.BuiltinExp builtin, LlvmLowerer lowerer)
{
	auto loc = exp.loc;
	final switch (builtin.kind) with (ir.BuiltinExp.Kind) {
	case ArrayPtr:
	case ArrayLength:
	case BuildVtable:
	case EnumMembers:
		break;
	case ArrayDup:
		if (builtin.children.length != 3) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		auto sexp = buildStatementExp(/*#ref*/loc);
		auto type = builtin.type;
		auto asStatic = cast(ir.StaticArrayType)realType(type);
		ir.Exp value = builtin.children[0];
		value = buildSlice(/*#ref*/loc, value);
		auto valueVar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, type, value);
		value = buildExpReference(/*#ref*/loc, valueVar, valueVar.name);

		auto startCast = buildCastSmart(/*#ref*/loc, buildSizeT(/*#ref*/loc, lp.target), builtin.children[1]);
		auto startVar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, buildSizeT(/*#ref*/loc, lp.target), startCast);
		auto start = buildExpReference(/*#ref*/loc, startVar, startVar.name);
		auto endCast = buildCastSmart(/*#ref*/loc, buildSizeT(/*#ref*/loc, lp.target), builtin.children[2]);
		auto endVar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, buildSizeT(/*#ref*/loc, lp.target), endCast);
		auto end = buildExpReference(/*#ref*/loc, endVar, endVar.name);


		auto length = buildSub(/*#ref*/loc, end, start);
		auto newExp = buildNewSmart(/*#ref*/loc, type, length);
		auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, type, newExp);
		auto evar = buildExpReference(/*#ref*/loc, var, var.name);
		auto sliceL = buildSlice(/*#ref*/loc, evar, copyExp(start), copyExp(end));
		auto sliceR = buildSlice(/*#ref*/loc, value, copyExp(start), copyExp(end));

		sexp.exp = buildAssign(/*#ref*/loc, sliceL, sliceR);
		exp = sexp;
		break;
	case AALength:
		if (builtin.children.length != 1) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCall(/*#ref*/exp.loc, lp.aaGetLength, builtin.children);
		break;
	case AAKeys:
		if (builtin.children.length != 1) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCastSmart(/*#ref*/exp.loc, builtin.type,
		                     buildCall(/*#ref*/exp.loc, lp.aaGetKeys, builtin.children));
		break;
	case AAValues:
		if (builtin.children.length != 1) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCastSmart(/*#ref*/exp.loc, builtin.type,
		                     buildCall(/*#ref*/exp.loc, lp.aaGetValues, builtin.children));
		break;
	case AARehash:
		if (builtin.children.length != 1) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCall(/*#ref*/exp.loc, lp.aaRehash, builtin.children);
		break;
	case AAGet:
		if (builtin.children.length != 3) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		auto aa = cast(ir.AAType)realType(getExpType(builtin.children[0]));
		if (aa is null) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		// Value* ptr = cast(Value*)vrt_aa_in_binop_*(aa, key);
		// Value val = <default>;
		auto sexp = buildStatementExp(/*#ref*/loc);
		ir.Function rtFn;
		if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
			rtFn = lp.aaInBinopPrimitive;
		} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
			rtFn = lp.aaInBinopArray;
		} else {
			rtFn = lp.aaInBinopPtr;
		}
		builtin.children[1] = lowerAAKeyCast(/*#ref*/loc, lp, getModuleFromScope(/*#ref*/loc, current),
			current, builtin.children[1], aa, lowerer);
		auto ptr = buildVariableSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, aa.value), ir.Variable.Storage.Function,
			"ptr");
		auto val = buildVariableSmart(/*#ref*/loc, aa.value, ir.Variable.Storage.Function, "val");
		ptr.assign = buildCall(/*#ref*/loc, rtFn, [builtin.children[0], builtin.children[1]]);
		ptr.assign = buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, aa.value), ptr.assign);
		val.assign = buildCastSmart(/*#ref*/loc, aa.value, builtin.children[2]);
		sexp.statements ~= ptr;
		sexp.statements ~= val;
		// if (ptr !is null) { val = *ptr; }
		auto assign = buildExpStat(/*#ref*/loc, buildAssign(/*#ref*/loc, buildExpReference(/*#ref*/loc, val, val.name),
			buildDeref(/*#ref*/loc, buildExpReference(/*#ref*/loc, ptr, ptr.name))));
		auto thenStat = buildBlockStat(/*#ref*/loc, null, current, assign);
		auto cond = buildBinOp(/*#ref*/loc, ir.BinOp.Op.NotIs, buildExpReference(/*#ref*/loc, ptr, ptr.name),
			buildConstantNull(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, aa.value)));
		auto ifStat = buildIfStat(/*#ref*/loc, cond, thenStat);
		sexp.statements ~= ifStat;
		sexp.exp = buildExpReference(/*#ref*/loc, val, val.name);
		exp = sexp;
		break;
	case AARemove:
		if (builtin.children.length != 2) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		auto aa = cast(ir.AAType)realType(getExpType(builtin.children[0]));
		if (aa is null) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		ir.Function rtfn;
		builtin.children[1] = lowerAAKeyCast(/*#ref*/loc, lp, getModuleFromScope(/*#ref*/loc, current),
			current, builtin.children[1], aa, lowerer);
		if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
			rtfn = lp.aaDeletePrimitive;
		} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
			rtfn = lp.aaDeleteArray;
		} else {
			rtfn = lp.aaDeletePtr;
		}
		exp = buildCall(/*#ref*/exp.loc, rtfn, builtin.children);
		break;
	case AAIn:
		if (builtin.children.length != 2) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		auto aa = cast(ir.AAType)realType(getExpType(builtin.children[0]));
		if (aa is null) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		bool keyIsArray = isArray(realType(aa.key));
		ir.Function rtfn;
		builtin.children[1] = lowerAAKeyCast(/*#ref*/loc, lp, getModuleFromScope(/*#ref*/loc, current),
			current, builtin.children[1], aa, lowerer);
		if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
			rtfn = lp.aaInBinopPrimitive;
		} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
			rtfn = lp.aaInBinopArray;
		} else {
			rtfn = lp.aaInBinopPtr;
		}
		exp = buildCall(/*#ref*/exp.loc, rtfn, builtin.children);
		exp = buildCast(/*#ref*/loc, builtin.type, exp);
		break;
	case AADup:
		if (builtin.children.length != 1) {
			throw panic(/*#ref*/exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCall(/*#ref*/loc, lp.aaDup, builtin.children);
		exp = buildCastSmart(/*#ref*/loc, builtin.type, exp);
		break;
	case Classinfo:
		panicAssert(exp, builtin.children.length == 1);
		auto iface = cast(ir._Interface)realType(getExpType(builtin.children[0]));
		auto ti = buildPtrSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, buildArrayType(/*#ref*/loc, copyTypeSmart(/*#ref*/loc, lp.tiClassInfo))));
		auto sexp = buildStatementExp(/*#ref*/loc);
		ir.Exp ptr = buildCastToVoidPtr(/*#ref*/loc, builtin.children[0]);
		if (iface !is null) {
			/* We need the class vtable. Each interface instance holds the
			 * amount it's set forward from the beginning of the class one,
			 * as the first entry in the interface layout table,
			 * so we just do `**cast(size_t**)cast(void*)iface` to get at it.
			 * Then we subtract that value from the pointer.
			 */
			auto offset = buildDeref(/*#ref*/loc, buildDeref(/*#ref*/loc,
				buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, buildSizeT(/*#ref*/loc, lp.target))), copyExp(/*#ref*/loc, ptr))));
			ptr = buildSub(/*#ref*/loc, ptr, offset);
		}
		auto tinfos = buildDeref(/*#ref*/loc, buildDeref(/*#ref*/loc, buildCastSmart(/*#ref*/loc, ti, ptr)));
		auto tvar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp,
		                                   buildArrayType(/*#ref*/loc,
		                                   copyTypeSmart(/*#ref*/loc, lp.tiClassInfo)), tinfos);
		ir.Exp tlen = buildArrayLength(/*#ref*/loc, lp.target, buildExpReference(/*#ref*/loc, tvar, tvar.name));
		tlen = buildSub(/*#ref*/loc, tlen, buildConstantSizeT(/*#ref*/loc, lp.target, 1));
		sexp.exp = buildIndex(/*#ref*/loc, buildExpReference(/*#ref*/loc, tvar, tvar.name), tlen);
		exp = buildCastSmart(/*#ref*/loc, lp.tiClassInfo, sexp);
		break;
	case PODCtor:
		panicAssert(exp, builtin.children.length == 1);
		panicAssert(exp, builtin.functions.length == 1);
		lowerStructUnionConstructor(lp, current, /*#ref*/exp, builtin);
		break;
	case VaStart:
		panicAssert(exp, builtin.children.length == 2);
		builtin.children[1] = buildArrayPtr(/*#ref*/loc, buildVoid(/*#ref*/loc), builtin.children[1]);
		exp = buildAssign(/*#ref*/loc, buildDeref(/*#ref*/loc, buildAddrOf(builtin.children[0])), builtin.children[1]);
		break;
	case VaEnd:
		panicAssert(exp, builtin.children.length == 1);
		exp = buildAssign(/*#ref*/loc, buildDeref(/*#ref*/loc, buildAddrOf(builtin.children[0])), buildConstantNull(/*#ref*/loc, buildVoidPtr(/*#ref*/loc)));
		break;
	case VaArg:
		panicAssert(exp, builtin.children.length == 1);
		auto vaexp = cast(ir.VaArgExp)builtin.children[0];
		panicAssert(exp, vaexp !is null);
		exp = lowerVaArg(/*#ref*/vaexp.loc, lp, vaexp);
		break;
	case UFCS:
	case Invalid:
		panicAssert(exp, false);
	}
}

ir.StatementExp lowerVaArg(ref in Location loc, LanguagePass lp, ir.VaArgExp vaexp)
{
	auto sexp = new ir.StatementExp();
	sexp.loc = loc;

	auto ptrToPtr = buildVariableSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, buildVoidPtr(/*#ref*/loc)), ir.Variable.Storage.Function, "ptrToPtr");
	ptrToPtr.assign = buildAddrOf(/*#ref*/loc, vaexp.arg);
	sexp.statements ~= ptrToPtr;

	auto cpy = buildVariableSmart(/*#ref*/loc, buildVoidPtr(/*#ref*/loc), ir.Variable.Storage.Function, "cpy");
	cpy.assign = buildDeref(/*#ref*/loc, ptrToPtr);
	sexp.statements ~= cpy;

	auto vlderef = buildDeref(/*#ref*/loc, ptrToPtr);
	auto tid = buildTypeidSmart(/*#ref*/loc, vaexp.type);
	auto sz = getSizeOf(/*#ref*/loc, lp, vaexp.type);
	auto assign = buildAddAssign(/*#ref*/loc, vlderef, sz);
	buildExpStat(/*#ref*/loc, sexp, assign);

	auto ptr = buildPtrSmart(/*#ref*/loc, vaexp.type);
	auto _cast = buildCastSmart(/*#ref*/loc, ptr, buildExpReference(/*#ref*/loc, cpy));
	auto deref = buildDeref(/*#ref*/loc, _cast);
	sexp.exp = deref;

	return sexp;
}

/*!
 * Lower an ExpReference, if needed.
 *
 * This rewrites them to lookup through the nested struct, if needed.
 *
 * Params:
 *   functionStack: A list of functions. Most recent at $-1, its parent at $-2, and so on.
 *   exp: A reference to the relevant expression.
 *   eref: The ExpReference to potentially lower.
 */
void lowerExpReference(ir.Function[] functionStack, ref ir.Exp exp, ir.ExpReference eref,
					   ir.Function func)
{
	bool isnested;
	foreach (pf; functionStack) {
		foreach (nf; pf.nestedFunctions) {
			if (func is nf) {
				isnested = true;
			}
		}
		if (isnested) {
			break;
		}
	}
	if (!isnested) {
		return;
	}
	auto np = functionStack[$-1].nestedVariable;
	exp = buildCreateDelegate(/*#ref*/exp.loc, buildExpReference(/*#ref*/np.loc, np, np.name), eref);
}

/*!
 * Lower a Postfix, if needed.
 *
 * This handles index operations, and interface pointers.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   parentFunc: The parent function where this postfix is held, or null.
 *   postfix: The Postfix to potentially lower.
 */
void lowerPostfix(LanguagePass lp, ir.Scope current, ir.Module thisModule,
                  ref ir.Exp exp, ir.Function parentFunc, ir.Postfix postfix,
				  LlvmLowerer lowerer)
{
	switch(postfix.op) {
	case ir.Postfix.Op.Index:
		lowerIndex(lp, current, thisModule, /*#ref*/exp, postfix, lowerer);
		break;
	default:
		break;
	}
	ir._Interface iface;
	if (isInterfacePointer(lp, postfix, current, /*#out*/iface)) {
		assert(iface !is null);
		auto cpostfix = cast(ir.Postfix) postfix.child;  // TODO: Calling returned interfaces directly.
		if (cpostfix is null || cpostfix.memberFunction is null) {
			throw makeExpected(/*#ref*/exp.loc, "interface");
		}
		auto func = cast(ir.Function) cpostfix.memberFunction.decl;
		if (func is null) {
			throw makeExpected(/*#ref*/exp.loc, "method");
		}
		auto loc = exp.loc;
		auto agg = cast(ir._Interface)realType(getExpType(cpostfix.child));
		panicAssert(postfix, agg !is null);
		auto store = lookupInGivenScopeOnly(lp, agg.layoutStruct.myScope, /*#ref*/loc, "__offset");
		auto fstore = lookupInGivenScopeOnly(lp, agg.layoutStruct.myScope, /*#ref*/loc, mangle(null, func));
		panicAssert(postfix, store !is null);
		panicAssert(postfix, fstore !is null);
		auto var = cast(ir.Variable)store.node;
		auto fvar = cast(ir.Variable)fstore.node;

		/* Manually lower the function type.
		 * We do this here because interfaces don't get called like a method,
		 * so we need to make sure everybody agrees on what it is that they're
		 * calling. (See test interface.13 and 14).
		 */
		fvar.type = copyType(func.type);
		auto ftype = cast(ir.FunctionType)fvar.type;
		ftype.params = buildVoidPtr(/*#ref*/loc) ~ ftype.params;
		ftype.isArgRef = false ~ ftype.isArgRef;
		ftype.isArgOut = false ~ ftype.isArgOut;
		ftype.hiddenParameter = false;

		panicAssert(postfix, var !is null);
		panicAssert(postfix, fvar !is null);
		auto handle = buildCastToVoidPtr(/*#ref*/loc, buildSub(/*#ref*/loc, buildCastSmart(/*#ref*/loc,
		                                 buildPtrSmart(/*#ref*/loc, buildUbyte(/*#ref*/loc)),
		                                 copyExp(cpostfix.child)),
		                                 buildAccessExp(/*#ref*/loc, buildDeref(/*#ref*/loc,
		                                 copyExp(cpostfix.child)), var)));
		exp = buildCall(/*#ref*/loc, buildAccessExp(/*#ref*/loc, buildDeref(/*#ref*/loc, cpostfix.child),
						fvar), handle ~ postfix.arguments);
	}
	lowerVarargCall(lp, current, postfix, parentFunc, /*#ref*/exp);
}

/*!
 * Lower a call to a varargs function.
 */
void lowerVarargCall(LanguagePass lp, ir.Scope current, ir.Postfix postfix, ir.Function func, ref ir.Exp exp)
{
	if (postfix.op != ir.Postfix.Op.Call) {
		return;
	}
	assert(func !is null);
	auto asFunctionType = cast(ir.CallableType)realType(getExpType(postfix.child));
	if (asFunctionType is null || !asFunctionType.hasVarArgs) {
		return;
	}

	if (asFunctionType.linkage == ir.Linkage.C) {
		/* Clang casts floats to doubles when passing them to variadic functions.
		 * I'm not sure *why*, but sure enough if we don't we lose data, so...
		 */
		foreach (ref argexp; postfix.arguments[asFunctionType.params.length .. $]) {
			auto ptype = getExpType(argexp);
			if (isF32(ptype)) {
				auto loc = argexp.loc;
				argexp = buildCastSmart(/*#ref*/loc, buildDouble(/*#ref*/loc), argexp);
			}
		}
	}

	if (asFunctionType.linkage != ir.Linkage.Volt) {
		return;
	}

	auto loc = postfix.loc;

	auto callNumArgs = postfix.arguments.length;
	auto funcNumArgs = asFunctionType.params.length;
	if (callNumArgs < funcNumArgs) {
		throw makeWrongNumberOfArguments(postfix, func, callNumArgs, funcNumArgs);
	}
	auto passSlice = postfix.arguments[0 .. funcNumArgs];
	auto varArgsSlice = postfix.arguments[funcNumArgs .. $];

	auto tinfoClass = lp.tiTypeInfo;
	auto tr = buildTypeReference(/*#ref*/postfix.loc, tinfoClass, tinfoClass.name);
	tr.loc = postfix.loc;

	auto sexp = buildStatementExp(/*#ref*/loc);
	auto numVarArgs = varArgsSlice.length;
	ir.Exp idsSlice, argsSlice;

	if (numVarArgs > 0) {
		auto idsType = buildStaticArrayTypeSmart(/*#ref*/loc, varArgsSlice.length, tr);
		auto argsType = buildStaticArrayTypeSmart(/*#ref*/loc, 0, buildVoid(/*#ref*/loc));
		auto ids = buildVariableAnonSmartAtTop(lp.errSink, /*#ref*/loc, func._body, idsType, null);
		auto args = buildVariableAnonSmartAtTop(lp.errSink, /*#ref*/loc, func._body, argsType, null);

		int[] sizes;
		size_t totalSize;
		ir.Type[] types;
		foreach (i, _exp; varArgsSlice) {
			auto etype = getExpType(_exp);
			auto mod = getModuleFromScope(/*#ref*/loc, current);
			if (mod.magicFlagD &&
					realType(etype).nodeType == ir.NodeType.Struct) {
				warning(/*#ref*/_exp.loc, "passing struct to var-arg function.");
			}

			auto ididx = buildIndex(/*#ref*/loc, buildExpReference(/*#ref*/loc, ids, ids.name), buildConstantSizeT(/*#ref*/loc, lp.target, i));
			buildExpStat(/*#ref*/loc, sexp, buildAssign(/*#ref*/loc, ididx, buildTypeidSmart(/*#ref*/loc, lp.tiTypeInfo, etype)));

			// *(cast(T*)arr.ptr + totalSize) = exp;
			auto argl = buildDeref(/*#ref*/loc, buildCastSmart(/*#ref*/loc, buildPtrSmart(/*#ref*/loc, etype),
						buildAdd(/*#ref*/loc, buildArrayPtr(/*#ref*/loc, buildVoid(/*#ref*/loc),
								buildExpReference(/*#ref*/loc, args, args.name)), buildConstantSizeT(/*#ref*/loc, lp.target, totalSize))));

			buildExpStat(/*#ref*/loc, sexp, buildAssign(/*#ref*/loc, argl, _exp));

			totalSize += size(lp.target, etype);
		}

		(cast(ir.StaticArrayType)args.type).length = totalSize;
		idsSlice = buildSlice(/*#ref*/loc, buildExpReference(/*#ref*/loc, ids, ids.name));
		argsSlice = buildSlice(/*#ref*/loc, buildExpReference(/*#ref*/loc, args, args.name));
	} else {
		auto idsType = buildArrayType(/*#ref*/loc, tr);
		auto argsType = buildArrayType(/*#ref*/loc, buildVoid(/*#ref*/loc));
		idsSlice = buildArrayLiteralSmart(/*#ref*/loc, idsType);
		argsSlice = buildArrayLiteralSmart(/*#ref*/loc, argsType);
	}

	postfix.arguments = passSlice ~ idsSlice ~ argsSlice;
	sexp.exp = postfix;
	exp = sexp;
}

void lowerGlobalAALiteral(LanguagePass lp, ir.Scope current, ir.Module mod, ir.Variable var)
{
	auto loc = var.loc;
	auto gctor = buildGlobalConstructor(lp.errSink, /*#ref*/loc, mod.children, current, "__ctor");
	ir.BinOp assign = buildAssign(/*#ref*/loc, var, var.assign);
	buildExpStat(/*#ref*/loc, gctor._body, assign);
	var.assign = null;
	buildReturnStat(/*#ref*/loc, gctor._body);
}

/*!
 * Lower an AA literal.
 *
 * Params:
 *   lp: The LanguagePass.
 *   current: The Scope where this code takes place.
 *   thisModule: The Module that this code is taking place in.
 *   exp: A reference to the relevant expression.
 *   assocArray: The AA literal to lower.
 */
void lowerAA(LanguagePass lp, ir.Scope current, ir.Module thisModule, ref ir.Exp exp,
             ir.AssocArray assocArray, LlvmLowerer lowerer)
{
	auto loc = exp.loc;
	auto aa = cast(ir.AAType)getExpType(exp);
	assert(aa !is null);

	auto statExp = buildStatementExp(/*#ref*/loc);
	auto aaNewFn = lp.aaNew;

	auto bs = cast(ir.BlockStatement)current.node;
	if (bs is null) {
		auto func = cast(ir.Function)current.node;
		if (func !is null) {
			bs = func._body;
		}
	}
	panicAssert(exp, bs !is null);

	auto var = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, bs, statExp,
		copyTypeSmart(/*#ref*/loc, aa), buildCall(/*#ref*/loc, aaNewFn, [
			cast(ir.Exp)buildTypeidSmart(/*#ref*/loc, lp.tiTypeInfo, aa.value),
			cast(ir.Exp)buildTypeidSmart(/*#ref*/loc, lp.tiTypeInfo, aa.key)
		], aaNewFn.name)
	);

	foreach (pair; assocArray.pairs) {
		auto key = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, bs, statExp,
			copyTypeSmart(/*#ref*/loc, aa.key), pair.key
		);

		auto value = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, bs, statExp,
			copyTypeSmart(/*#ref*/loc, aa.value), pair.value
		);

		lowerAAInsert(/*#ref*/loc, lp, thisModule, current, statExp,
			 aa, var, buildExpReference(/*#ref*/loc, key), buildExpReference(/*#ref*/loc, value),
			 lowerer, false, false
		);
	}

	statExp.exp = buildExpReference(/*#ref*/loc, var);
	exp = statExp;
}

/*!
 * Rewrite Struct(args) to call their constructors.
 */
void lowerStructUnionConstructor(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.BuiltinExp builtin)
{
	auto agg = cast(ir.PODAggregate)realType(builtin.type);
	if (agg is null || agg.constructors.length == 0) {
		return;
	}
	auto postfix = cast(ir.Postfix)builtin.children[0];
	auto loc = exp.loc;
	auto ctor = builtin.functions[0];
	auto sexp = buildStatementExp(/*#ref*/loc);
	auto svar = buildVariableAnonSmart(lp.errSink, /*#ref*/loc, current, sexp, agg, null);
	auto args = buildCast(/*#ref*/loc, buildVoidPtr(/*#ref*/loc), buildAddrOf(/*#ref*/loc,
		buildExpReference(/*#ref*/loc, svar, svar.name))) ~ postfix.arguments;
	auto ctorCall = buildCall(/*#ref*/loc, ctor, args);

	buildExpStat(/*#ref*/loc, sexp, ctorCall);
	sexp.exp = buildExpReference(/*#ref*/loc, svar, svar.name);
	exp = sexp;
}

ir.Exp zeroVariableIfNeeded(LanguagePass lp, ir.Variable var)
{
	auto s = .size(lp.target, var.type);
	if (s < 64) {
		return null;
	}

	auto loc = var.loc;
	auto llvmMemset = lp.target.isP64 ? lp.llvmMemset64 : lp.llvmMemset32;
	auto memset = buildExpReference(/*#ref*/loc, llvmMemset, llvmMemset.name);
	auto ptr = buildCastToVoidPtr(/*#ref*/loc, buildAddrOf(/*#ref*/loc, buildExpReference(/*#ref*/loc, var, var.name)));
	auto zero = buildConstantUbyte(/*#ref*/loc, 0);
	auto size = buildConstantSizeT(/*#ref*/loc, lp.target, s);
	auto alignment = buildConstantInt(/*#ref*/loc, 0);
	auto isVolatile = buildConstantBool(/*#ref*/loc, false);
	return buildCall(/*#ref*/loc, memset, [ptr, zero, size, alignment, isVolatile]);
}

void zeroVariablesIfNeeded(LanguagePass lp, ir.BlockStatement bs)
{
	for (size_t i = 0; i < bs.statements.length; ++i) {
		auto var = cast(ir.Variable)bs.statements[i];
		if (var is null || var.assign !is null || var.specialInitValue) {
			continue;
		}
		auto exp = zeroVariableIfNeeded(lp, var);
		if (exp is null) {
			continue;
		}
		var.noInitialise = true;
		bs.statements = bs.statements[0 .. i+1] ~ buildExpStat(/*#ref*/exp.loc, exp) ~ bs.statements[i+1 .. $];
		i++;
	}
}

/*!
 * Calls the correct functions where they need to be called to lower a module.
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
		this.V_P64 = lp.ver.isP64;
	}

	/*!
	 * Perform all lower operations on a given module.
	 *
	 * Params:
	 *   m: The module to lower.
	 */
	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ir.BlockStatement bs)
	{
		super.enter(bs);
		panicAssert(bs, functionStack.length > 0);
		for (size_t i = 0; i < bs.statements.length; ++i) {
			auto as = cast(ir.AssertStatement)bs.statements[i];
			if (as !is null && !as.isStatic) {
				bs.statements[i] = lowerAssertIf(lp, current, as);
			}
			auto fes = cast(ir.ForeachStatement)bs.statements[i];
			if (fes !is null) {
				bs.statements[i] = lowerForeach(fes, lp, current);
			}
		}

		insertBinOpAssignsForNestedVariableAssigns(lp, bs);
		zeroVariablesIfNeeded(lp, bs);
		return Continue;
	}

	override Status enter(ir.Function func)
	{
		ir.Function parent;
		if (functionStack.length == 1) {
			parent = functionStack[0];
		} else {
			assert(functionStack.length == 0);
		}

		nestLowererFunction(lp, parent, func);

		super.enter(func);

		return Continue;
	}

	override Status leave(ir.ThrowStatement t)
	{
		lowerThrow(lp, t);
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
			if (asPostfix is null) {
				return Continue;
			}

			auto leftType = getExpType(asPostfix.child);
			if (leftType !is null &&
				leftType.nodeType == ir.NodeType.AAType &&
				asPostfix.op == ir.Postfix.Op.Index) {
				acceptExp(/*#ref*/asPostfix.child, this);
				acceptExp(/*#ref*/asPostfix.arguments[0], this);
				acceptExp(/*#ref*/binOp.right, this);

				if (binOp.op == ir.BinOp.Op.Assign) {
					lowerAssignAA(lp, current, thisModule, /*#ref*/exp, binOp, asPostfix,
								  cast(ir.AAType)leftType, this);
				} else {
					lowerOpAssignAA(lp, current, thisModule, /*#ref*/exp, binOp, asPostfix,
									cast(ir.AAType)leftType, this);
				}
				return ContinueParent;
			}
			break;
		default:
			break;
		}
		return Continue;
	}

	override Status enter(ir.Variable var)
	{
		if (functionStack.length == 0 && var.assign !is null &&
			var.assign.nodeType == ir.NodeType.AssocArray) {
			lowerGlobalAALiteral(lp, current, thisModule, var);
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.BinOp binOp)
	{
		/*
		 * We do this on the leave function so we know that
		 * any children have been lowered as well.
		 */
		switch(binOp.op) {
		case ir.BinOp.Op.Assign:
			lowerAssign(lp, thisModule, /*#ref*/exp, binOp);
			break;
		case ir.BinOp.Op.Cat:
			lowerCat(lp, thisModule, /*#ref*/exp, binOp);
			break;
		case ir.BinOp.Op.CatAssign:
			lowerCatAssign(lp, thisModule, /*#ref*/exp, binOp);
			break;
		case ir.BinOp.Op.NotEqual:
		case ir.BinOp.Op.Equal:
			lowerEqual(lp, thisModule, /*#ref*/exp, binOp);
			break;
		default:
			break;
		}
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.BuiltinExp builtin)
	{
		lowerBuiltin(lp, current, /*#ref*/exp, builtin, this);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.ArrayLiteral al)
	{
		if (al.exps.length > 0 && functionStack.length > 0) {
			lowerArrayLiteral(lp, current, /*#ref*/exp, al);
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.AssocArray assocArray)
	{
		lowerAA(lp, current, thisModule, /*#ref*/exp, assocArray, this);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Unary uexp)
	{
		lowerInterfaceCast(/*#ref*/exp.loc, lp, current, uexp, /*#ref*/exp);
		if (functionStack.length > 0) {
			lowerArrayCast(/*#ref*/exp.loc, lp, current, uexp, /*#ref*/exp);
		}

		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Postfix postfix)
	{
		auto oldExp = exp;
		lowerPostfix(lp, current, thisModule, /*#ref*/exp,
			functionStack.length == 0 ? null : functionStack[$-1], postfix, this);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.PropertyExp prop)
	{
		lowerProperty(lp, /*#ref*/exp, prop);
		auto pfix = cast(ir.Postfix)exp;
		if (pfix !is null) {
			lowerPostfix(lp, current, thisModule, /*#ref*/exp,
				functionStack.length == 0 ? null : functionStack[$-1], pfix, this);
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.ComposableString cs)
	{
		ir.Function currentFunc = functionStack.length == 0 ? null : functionStack[$-1];
		lowerComposableString(lp, current, currentFunc, /*#ref*/exp, cs, this);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.StructLiteral literal)
	{
		if (functionStack.length == 0) {
			// Global struct literals can use LLVM's native handling.
			return Continue;
		}
		lowerStructLiteral(lp, current, /*#ref*/exp, literal);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.AccessExp ae)
	{
		// This lists the cases where we need to rewrite (reversed).
		auto child = cast(ir.Postfix) ae.child;
		if (child is null || child.op != ir.Postfix.Op.Call) {
			return Continue;
		}

		auto type = realType(getExpType(ae.child));
		if (type.nodeType != ir.NodeType.Union &&
			type.nodeType != ir.NodeType.Struct) {
			return Continue;
		}
		lowerStructLookupViaFunctionCall(lp, current, /*#ref*/exp, ae, type);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		ir.Function currentFunc = functionStack.length == 0 ? null : functionStack[$-1];
		bool replaced = replaceNested(lp, /*#ref*/exp, eref, currentFunc);
		if (replaced) {
			return Continue;
		}
		auto func = cast(ir.Function) eref.decl;
		if (func is null) {
			return Continue;
		}
		if (functionStack.length == 0 || functionStack[$-1].nestedVariable is null) {
			return Continue;
		}
		lowerExpReference(functionStack, /*#ref*/exp, eref, func);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.StringImport simport)
	{
		lowerStringImport(lp.driver, /*#ref*/exp, simport);
		return Continue;
	}
}
