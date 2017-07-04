// Copyright © 2013-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.lowerer.llvmlowerer;

import watt.conv : toString;
import watt.text.format : format;
import watt.io.file : read, exists;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;
import volt.interfaces;
import volt.token.location;
import volt.visitor.visitor;
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
		bool buildif=true, bool aaIsPointer=true) {
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
		auto thenState = buildBlockStat(loc, statExp, current);
		varExp = buildExpReference(loc, var, var.name);
		ir.Exp[] args = [ cast(ir.Exp)buildTypeidSmart(loc, lp, aa.value),
		                  cast(ir.Exp)buildTypeidSmart(loc, lp, aa.key)
		];
		buildExpStat(loc, thenState,
			buildAssign(loc,
				aaIsPointer ? buildDeref(loc, varExp) : varExp,
				buildCall(loc, aaNewFn, args, aaNewFn.name
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
			lowerAAKeyCast(loc, lp, thisModule, current, key, aa),
			buildCastToVoidPtr(loc, buildAddrOf(value))
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
		ir.StatementExp statExp, ir.AAType aa, ir.Variable var, ir.Exp key, ir.Exp store) {
	ir.Function inAAFn;
	if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
		inAAFn = lp.aaInPrimitive;
	} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
		inAAFn = lp.aaInArray;
	} else {
		inAAFn = lp.aaInPtr;
	}

	auto thenState = buildBlockStat(loc, statExp, current);

	ir.Exp locstr = buildConstantString(loc, format("%s:%s", loc.filename, loc.line), false);

	buildExpStat(loc, thenState, buildCall(loc, lp.ehThrowKeyNotFoundErrorFunc, [locstr]));

	buildIfStat(loc, statExp,
		buildBinOp(loc, ir.BinOp.Op.Equal,
			buildCall(loc, inAAFn, [
				buildDeref(loc, var),
				lowerAAKeyCast(loc, lp, thisModule, current, key, aa),
				buildCastToVoidPtr(loc,
					buildAddrOf(loc, store)
				)
			], inAAFn.name),
			buildConstantBool(loc, false)
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
                      ir.Scope current, ir.Exp key, ir.AAType aa)
{
	return lowerAACast(loc, lp, thisModule, current, key, aa.key);
}

ir.Exp lowerAAValueCast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
                      ir.Scope current, ir.Exp key, ir.AAType aa)
{
	return lowerAACast(loc, lp, thisModule, current, key, aa.value);
}

ir.Exp lowerAACast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
                      ir.Scope current, ir.Exp key, ir.Type t)
{
	if (t.nodeType == ir.NodeType.PrimitiveType) {
		auto prim = cast(ir.PrimitiveType)t;

		assert(prim.type != ir.PrimitiveType.Kind.Real);

		if (prim.type == ir.PrimitiveType.Kind.Float ||
			prim.type == ir.PrimitiveType.Kind.Double) {
			auto type = prim.type == ir.PrimitiveType.Kind.Double ?
				buildUlong(loc) : buildInt(loc);

			key = buildCastSmart(loc, type, key);
		}

		key = buildCastSmart(loc, buildUlong(loc), key);
	} else {
		key = lowerStructOrArrayAACast(loc, lp, thisModule, current, key, t);
	}

	return key;
}

ir.Exp lowerAggregateAACast(ref in Location loc, LanguagePass lp, ir.Module thisModule,
						ir.Scope current, ir.Exp key, ir.Aggregate st)
{
	auto sexp = buildStatementExp(loc);
	// aggptr := new Aggregate;
	auto aggptr = buildVariableSmart(loc, buildPtrSmart(loc, st), ir.Variable.Storage.Function, "aggptr");
	aggptr.assign = buildNewSmart(loc, st);
	sexp.statements ~= aggptr;
	// *aggptr = st;
	auto deref = buildDeref(loc, buildExpReference(loc, aggptr, aggptr.name));
	auto assign = buildAssign(loc, deref, key);
	buildExpStat(loc, sexp, assign);
	// return aggptr;
	sexp.exp = buildExpReference(loc, aggptr, aggptr.name);
	return buildCastToVoidPtr(loc, sexp);
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
                            ir.Scope current, ir.Exp key, ir.Type t)
{
	if (t.nodeType != ir.NodeType.ArrayType) {
		auto st = cast(ir.Aggregate)realType(t);
		panicAssert(key, st !is null);
		return lowerAggregateAACast(loc, lp, thisModule, current, key, st);
	}

	ir.Type base = buildUlong(loc);
	auto at = t.toArrayTypeChecked();
	if (at !is null) {
		base = at.base;
	}
	auto concatfn = getArrayAppendFunction(loc, lp, thisModule,
	                                       buildArrayTypeSmart(loc, base),
	                                       base, false);
	auto keysfn = lp.aaGetKeys;
	auto valuesfn = lp.aaGetValues;

	// ulong[] array;
	auto atype = buildArrayTypeSmart(loc, base);
	auto sexp = buildStatementExp(loc);
	auto var = buildVariableSmart(loc, copyTypeSmart(loc, atype),
	                              ir.Variable.Storage.Function, "array");
	sexp.statements ~= var;

	ir.ExpReference eref(ir.Variable v)
	{
		return buildExpReference(v.loc, v, v.name);
	}

	void addElement(ir.Exp e, ref ir.Node[] statements)
	{
		auto call = buildCall(loc, concatfn, [eref(var), e], concatfn.name);
		statements ~= buildExpStat(loc, buildAssign(loc, eref(var), call));
	}

	// Filled in with gatherAggregate, as DMD won't look forward for inline functions.
	void delegate(ir.Aggregate) aggdg;

	void gatherType(ir.Type t, ir.Exp e, ref ir.Node[] statements)
	{
		switch (t.nodeType) {
		case ir.NodeType.ArrayType:
			auto atype = cast(ir.ArrayType)t;
			ir.ForStatement forStatement;
			ir.Variable index;
			buildForStatement(loc, lp.target, current, buildArrayLength(loc, lp.target, e), forStatement, index);
			gatherType(realType(atype.base), buildIndex(loc, e, eref(index)),
			           forStatement.block.statements);
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
			addElement(buildCastSmart(loc, base, e), statements);
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
			auto store = lookupInGivenScopeOnly(lp, agg.myScope, loc, var.name);
			if (store is null) {
				continue;
			}
			auto rtype = realType(var.type);
			gatherType(rtype, buildAccessExp(loc, copyExp(key), var), sexp.statements);
		}
	}

	version (Volt) {
		aggdg = cast(typeof(aggdg))gatherAggregate;
	} else {
		aggdg = &gatherAggregate;
	}

	gatherType(realType(t), key, sexp.statements);

	// ubyte[] barray;
	auto oarray = buildArrayType(loc, buildUbyte(loc));
	auto outvar = buildVariableSmart(loc, oarray, ir.Variable.Storage.Function, "barray");
	sexp.statements ~= outvar;

	// barray.ptr = cast(ubyte*) array.ptr;
	auto ptrcast = buildCastSmart(loc, buildPtrSmart(loc, buildUbyte(loc)),
	                              buildArrayPtr(loc, atype.base, eref(var)));
	auto ptrass = buildAssign(loc, buildArrayPtr(loc, oarray.base, eref(outvar)), ptrcast);
	buildExpStat(loc, sexp, ptrass);

	// barray.length = exps.length * typeid(ulong).size;
	auto lenaccess = buildArrayLength(loc, lp.target, eref(outvar));
	auto mul = buildBinOp(loc, ir.BinOp.Op.Mul, buildArrayLength(loc, lp.target, eref(var)),
	                      buildConstantSizeT(loc, lp.target, size(lp.target, base)));
	auto lenass = buildAssign(loc, lenaccess, mul);
	buildExpStat(loc, sexp, lenass);

	sexp.exp = eref(outvar);
	return buildCastSmart(loc, buildArrayType(loc, buildVoid(loc)), sexp);
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
	auto expRef = buildExpReference(prop.loc, prop.getFn, name);

	if (prop.child is null) {
		exp = buildCall(prop.loc, expRef, []);
	} else {
		exp = buildMemberCall(prop.loc,
		                      prop.child,
		                      expRef, name, []);
	}
}

//! Build an if statement based on a runtime assert.
ir.IfStatement lowerAssertIf(LanguagePass lp, ir.Scope current, ir.AssertStatement as)
{
	panicAssert(as, !as.isStatic);
	auto loc = as.loc;
	ir.Exp message = as.message;
	if (message is null) {
		message = buildConstantString(loc, "assertion failure");
	}
	assert(message !is null);
	ir.Exp locstr = buildConstantString(loc, format("%s:%s", as.loc.filename, as.loc.line), false);
	auto theThrow = buildExpStat(loc, buildCall(loc, lp.ehThrowAssertErrorFunc, [locstr, message]));
	auto thenBlock = buildBlockStat(loc, null, current, theThrow);
	auto ifS = buildIfStat(loc, buildNot(loc, as.condition), thenBlock);
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
	t.exp = buildCall(t.loc, lp.ehThrowFunc, [t.exp,
	                  buildConstantString(t.loc, format("%s:%s", t.loc.filename, t.loc.line), false)]);
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
	auto str = driver.stringImport(exp.loc, fname);

	// Build and replace.
	exp = buildConstantString(exp.loc, str, false);
}

/*!
 * Turn `Struct a = {1, "banana"};`
 * into `Struct a; a.firstField = 1; b.secondField = "banana";`.
 *
 * Params:
 *   current: The scope where the StructLiteral occurs.
 *   exp: The expression of the StructLiteral.
 *   literal: The StructLiteral to lower.
 */
void lowerStructLiteral(ir.Scope current, ref ir.Exp exp, ir.StructLiteral literal)
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
	auto sexp = buildStatementExp(loc);
	auto var = buildVariableAnonSmart(loc, current, sexp, theStruct, null);

	// Assign the literal expressions to the fields.
	foreach (i, e; literal.exps) {
		auto eref = buildExpReference(loc, var, var.name);
		auto lh = buildAccessExp(loc, eref, fields[i]);
		auto assign = buildAssign(loc, lh, e);
		buildExpStat(loc, sexp, assign);
	}

	sexp.exp = buildExpReference(loc, var, var.name);
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
                ref ir.Exp exp, ir.Postfix postfix)
{
	auto type = getExpType(postfix.child);
	if (type.nodeType == ir.NodeType.AAType) {
		lowerIndexAA(lp, current, thisModule, exp, postfix, cast(ir.AAType)type);
	}
	// LLVM appears to have some issues with small indices.
	// If this is being indexed by a small type, cast it up.
	if (postfix.arguments.length > 0) {
		panicAssert(exp, postfix.arguments.length == 1);
		auto prim = cast(ir.PrimitiveType)realType(getExpType(postfix.arguments[0]));
		if (prim !is null && size(lp.target, prim) < 4/*Smaller than a 32 bit integer.*/) {
			auto loc = postfix.arguments[0].loc;
			postfix.arguments[0] = buildCastSmart(buildInt(loc), postfix.arguments[0]);
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
                  ref ir.Exp exp, ir.Postfix postfix, ir.AAType aa)
{
	auto loc = postfix.loc;
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

	lowerAALookup(loc, lp, thisModule, current, statExp, aa, var,
		buildExpReference(loc, key, key.name),
		buildExpReference(loc, store, store.name)
	);

	statExp.exp = buildExpReference(loc, store);

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

	lowerAssignArray(lp, thisModule, exp, binOp, asPostfix, cast(ir.ArrayType)leftType);
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

	auto func = getArrayCopyFunction(loc, lp, thisModule, leftType);
	exp = buildCall(loc, func, [asPostfix, binOp.right], func.name);
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
                   ref ir.Exp exp, ir.BinOp binOp, ir.Postfix asPostfix, ir.AAType aa)
{
	auto loc = binOp.loc;
	assert(asPostfix.op == ir.Postfix.Op.Index);
	auto statExp = buildStatementExp(loc);

	auto bs = cast(ir.BlockStatement)current.node;
	if (bs is null) {
		auto func = cast(ir.Function)current.node;
		if (func !is null) {
			bs = func._body;
		}
	}
	panicAssert(exp, bs !is null);

	auto var = buildVariableAnonSmart(loc, bs, statExp,
		buildPtrSmart(loc, aa), buildAddrOf(loc, asPostfix.child)
	);

	auto key = buildVariableAnonSmart(loc, bs, statExp,
		copyTypeSmart(loc, aa.key), asPostfix.arguments[0]
	);
	auto value = buildVariableAnonSmart(loc, bs, statExp,
		copyTypeSmart(loc, aa.value), binOp.right
	);

	lowerAAInsert(loc, lp, thisModule, current, statExp, aa, var,
			buildExpReference(loc, key, key.name),
			buildExpReference(loc, value, value.name)
	);

	statExp.exp = buildExpReference(loc, value, value.name);
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
                     ref ir.Exp exp, ir.BinOp binOp, ir.Postfix asPostfix, ir.AAType aa)
{
	auto loc = binOp.loc;
	assert(asPostfix.op == ir.Postfix.Op.Index);
	auto statExp = buildStatementExp(loc);

	auto var = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
		buildPtrSmart(loc, aa), null
	);
	buildExpStat(loc, statExp,
		buildAssign(loc, var, buildAddrOf(loc, asPostfix.child))
	);

	auto key = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
		copyTypeSmart(loc, aa.key), null
	);
	buildExpStat(loc, statExp,
		buildAssign(loc, key, asPostfix.arguments[0])
	);
	auto store = buildVariableAnonSmart(loc, cast(ir.BlockStatement)current.node, statExp,
		copyTypeSmart(loc, aa.value), null
	);

	lowerAALookup(loc, lp, thisModule, current, statExp, aa, var,
		buildExpReference(loc, key, key.name),
		buildExpReference(loc, store, store.name)
	);

	buildExpStat(loc, statExp,
		buildBinOp(loc, binOp.op,
			buildExpReference(loc, store, store.name),
			binOp.right
		)
	);

	lowerAAInsert(loc, lp, thisModule, current, statExp, aa, var,
		buildExpReference(loc, key, key.name),
		buildExpReference(loc, store, store.name),
		false
	);

	statExp.exp = buildExpReference(loc, store, store.name);
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
			throw panic(exp.loc, "array concat failure");
		}
	}

	if (typesEqual(realType(elementType, true), realType(arrayType.base, true))) {
		// T[] ~ T
		ir.Function func;
		if (reversed) {
			func = getArrayPrependFunction(loc, lp, thisModule, arrayType, elementType);
		} else {
			func = getArrayAppendFunction(loc, lp, thisModule, arrayType, elementType, false);
		}
		exp = buildCall(loc, func, [binOp.left, binOp.right], func.name);
	} else {
		// T[] ~ T[]
		auto func = getArrayConcatFunction(loc, lp, thisModule, arrayType, false);
		exp = buildCall(loc, func, [binOp.left, binOp.right], func.name);
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
		auto func = getArrayAppendFunction(loc, lp, thisModule, leftArrayType, rightType, true);
		exp = buildCall(loc, func, [buildAddrOf(binOp.left), binOp.right], func.name);
	} else {
		auto func = getArrayConcatFunction(loc, lp, thisModule, leftArrayType, true);
		exp = buildCall(loc, func, [buildAddrOf(binOp.left), binOp.right], func.name);
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

	auto func = getArrayCmpFunction(loc, lp, thisModule, leftArrayType, binOp.op == ir.BinOp.Op.NotEqual);
	exp = buildCall(loc, func, [binOp.left, binOp.right], func.name);
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
	auto store = lookupInGivenScopeOnly(lp, agg.myScope, loc, mangle(iface));
	panicAssert(uexp, store !is null);
	auto var = cast(ir.Variable)store.node;
	panicAssert(uexp, var !is null);
	exp = buildAddrOf(loc, buildAccessExp(loc, uexp.value, var));
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
			uexp.value = buildSlice(exp.loc, uexp.value, []);
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
	auto var = buildVariableSmart(loc, copyTypeSmart(loc, fromArray), ir.Variable.Storage.Function, varName);
	var.assign = uexp.value;
	sexp.statements ~= var;

	if (fromSz % toSz) {
		//     vrt_throw_slice_error(arr.length, typeid(T).size);
		auto ln = buildArrayLength(loc, lp.target, buildExpReference(loc, var, varName));
		auto sz = getSizeOf(loc, lp, toArray.base);
		ir.Exp locstr = buildConstantString(loc, format("%s:%s", exp.loc.filename, exp.loc.line), false);
		auto rtCall = buildCall(loc, lp.ehThrowSliceErrorFunc, [locstr]);
		auto bs = buildBlockStat(loc, rtCall, current, buildExpStat(loc, rtCall));
		auto check = buildBinOp(loc, ir.BinOp.Op.NotEqual,
		                        buildBinOp(loc, ir.BinOp.Op.Mod, ln, sz),
		                        buildConstantSizeT(loc, lp.target, 0));
		auto _if = buildIfStat(loc, check, bs);
		sexp.statements ~= _if;
	}

	auto inLength = buildArrayLength(loc, lp.target, buildExpReference(loc, var, varName));
	ir.Exp lengthTweak;
	if (fromSz == toSz) {
		lengthTweak = inLength;
	} else if (!decreasing) {
		lengthTweak = buildBinOp(loc, ir.BinOp.Op.Div, inLength,
		                         buildConstantSizeT(loc, lp.target, biggestSz));
	} else {
		lengthTweak = buildBinOp(loc, ir.BinOp.Op.Mul, inLength,
		                         buildConstantSizeT(loc, lp.target, biggestSz));
	}

	auto ptrType = buildPtrSmart(loc, toArray.base);
	auto ptrIn = buildArrayPtr(loc, fromArray.base, buildExpReference(loc, var, varName));
	auto ptrOut = buildCast(loc, ptrType, ptrIn);
	sexp.exp = buildSlice(loc, ptrOut, buildConstantSizeT(loc, lp.target, 0), lengthTweak);
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
	auto statExp = buildStatementExp(loc);
	auto host = getParentFunction(current);
	auto var = buildVariableAnonSmart(loc, host._body, statExp, type,
	                                  ae.child);
	ae.child = buildExpReference(loc, var, var.name);
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
			throw makeExpected(fes.beginIntegerRange.loc,
			                   "integral beginning and end of range");
		}
		panicAssert(fes, typesEqual(begin, end));
		if (v.type is null) {
			v.type = copyType(begin);
		}
		v.assign = fes.reverse ?
		           buildSub(loc, fes.endIntegerRange, buildConstantInt(loc, 1)) :
		           fes.beginIntegerRange;

		auto cmpRef = buildExpReference(v.loc, v, v.name);
		auto incRef = buildExpReference(v.loc, v, v.name);
		fs.test = buildBinOp(loc,
		                     fes.reverse ? ir.BinOp.Op.GreaterEqual : ir.BinOp.Op.Less,
		                     cmpRef,
		                     buildCastSmart(loc, begin,
		                     fes.reverse ? fes.beginIntegerRange : fes.endIntegerRange));
		fs.increments ~= fes.reverse ? buildDecrement(v.loc, incRef) :
		                 buildIncrement(v.loc, incRef);
		return fs;
	}


	// foreach (e; a) => foreach (e; auto _anon = a)
	auto sexp = buildStatementExp(loc);

	// foreach (i, e; array) => for (size_t i = 0; i < array.length; i++) auto e = array[i]; ...
	// foreach_reverse (i, e; array) => for (size_t i = array.length - 1; i+1 >= 0; i--) auto e = array[i]; ..
	auto aggType = realType(getExpType(fes.aggregate));

	if (aggType.nodeType == ir.NodeType.ArrayType ||
	    aggType.nodeType == ir.NodeType.StaticArrayType) {
	    //
		aggType = realType(getExpType(buildSlice(loc, fes.aggregate, [])));
		auto anonVar = buildVariableAnonSmart(loc, current, sexp, aggType,
		                                      buildSlice(loc, fes.aggregate, []));
		anonVar.type.mangledName = mangle(aggType);
		scope (exit) fs.initVars = anonVar ~ fs.initVars;
		ir.ExpReference aggref() { return buildExpReference(loc, anonVar, anonVar.name); }
		fes.aggregate = aggref();

		// i = 0 / i = array.length
		ir.Variable indexVar, elementVar;
		ir.Exp indexAssign;
		if (!fes.reverse) {
			indexAssign = buildConstantSizeT(loc, lp.target, 0);
		} else {
			indexAssign = buildArrayLength(loc, lp.target, aggref());
		}
		if (fs.initVars.length == 2) {
			indexVar = fs.initVars[0];
			if (indexVar.type is null) {
				indexVar.type = buildSizeT(loc, lp.target);
			}
			indexVar.assign = indexAssign;
			elementVar = fs.initVars[1];
		} else {
			panicAssert(fes, fs.initVars.length == 1);
			indexVar = buildVariable(loc, buildSizeT(loc, lp.target),
			                         ir.Variable.Storage.Function, "i", indexAssign);
			elementVar = fs.initVars[0];
		}

		// Move element var to statements so it can be const/immutable.
		fs.initVars = [indexVar];
		fs.block.statements = [cast(ir.Node)elementVar] ~ fs.block.statements;

		ir.Variable nextIndexVar;  // This is what we pass when decoding strings.
		if (fes.decodeFunction !is null && !fes.reverse) {
			auto ivar = buildExpReference(indexVar.loc, indexVar, indexVar.name);
			nextIndexVar = buildVariable(loc, buildSizeT(loc, lp.target),
			                             ir.Variable.Storage.Function, "__nexti", ivar);
			fs.initVars ~= nextIndexVar;
		}



		// i < array.length / i + 1 >= 0
		auto tref = buildExpReference(indexVar.loc, indexVar, indexVar.name);
		auto rtref = buildDecrement(loc, tref);
		auto length = buildArrayLength(loc, lp.target, fes.aggregate);
		auto zero = buildConstantSizeT(loc, lp.target, 0);
		fs.test = buildBinOp(loc, fes.reverse ? ir.BinOp.Op.Greater : ir.BinOp.Op.Less,
							 fes.reverse ? rtref : tref,
							 fes.reverse ? zero : length);

		// auto e = array[i]; i++/i--
		auto incRef = buildExpReference(indexVar.loc, indexVar, indexVar.name);
		auto accessRef = buildExpReference(indexVar.loc, indexVar, indexVar.name);
		auto eRef = buildExpReference(elementVar.loc, elementVar, elementVar.name);
		if (fes.decodeFunction !is null) {  // foreach (i, dchar c; str)
			auto dfn = buildExpReference(loc, fes.decodeFunction, fes.decodeFunction.name);
			if (!fes.reverse) {
				elementVar.assign = buildCall(loc, dfn,
				    [cast(ir.Exp)aggref(), cast(ir.Exp)buildExpReference(loc, nextIndexVar,
				    nextIndexVar.name)]);
				fs.increments ~= buildAssign(loc, indexVar, nextIndexVar);
			} else {
				elementVar.assign = buildCall(loc, dfn, [cast(ir.Exp)aggref(),
				    cast(ir.Exp)buildExpReference(indexVar.loc, indexVar, indexVar.name)]);
			}
		} else {
			elementVar.assign = buildIndex(incRef.loc, aggref(), accessRef);
			if (!fes.reverse) {
				fs.increments ~= buildIncrement(incRef.loc, incRef);
			}
		}



		foreach (i, ivar; fes.itervars) {
			if (!fes.refvars[i]) {
				continue;
			}
			if (i == 0 && fes.itervars.length > 1) {
				throw makeForeachIndexRef(fes.loc);
			}
			auto nr = new ExpReferenceReplacer(ivar, elementVar.assign);
			accept(fs.block, nr);
		}

		return fs;
	}

	// foreach (k, v; aa) => for (size_t i; i < aa.keys.length; i++) k = aa.keys[i]; v = aa[k];
	// foreach_reverse => error, as order is undefined.
	auto aaanonVar = buildVariableAnonSmart(loc, current, sexp, aggType, fes.aggregate);
	aaanonVar.type.mangledName = mangle(aggType);
	scope (exit) fs.initVars = aaanonVar ~ fs.initVars;
	ir.ExpReference aaaggref() { return buildExpReference(loc, aaanonVar, aaanonVar.name); }
	fes.aggregate = aaaggref();
	auto aa = cast(ir.AAType) aggType;
	if (aa !is null) {
		ir.Exp buildAACall(ir.Function func, ir.Type outType)
		{
			auto eref = buildExpReference(loc, func, func.name);
			return buildCastSmart(loc, outType, buildCall(loc, eref,
			       [cast(ir.Exp)buildCastToVoidPtr(loc, aaaggref())]));
		}

		if (fes.reverse) {
			throw makeForeachReverseOverAA(fes);
		}
		if (fs.initVars.length != 1 && fs.initVars.length != 2) {
			throw makeExpected(fes.loc, "1 or 2 iteration variables");
		}

		auto valVar = fs.initVars[0];
		ir.Variable keyVar;
		if (fs.initVars.length == 2) {
			keyVar = valVar;
			valVar = fs.initVars[1];
		} else {
			keyVar = buildVariable(loc, null, ir.Variable.Storage.Function,
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
			valVar.type = copyTypeSmart(loc, aa.value);
		}
		if (keyVar.type is null) {
			keyVar.type = copyTypeSmart(loc, aa.key);
		}
		auto indexVar = buildVariable(
			loc,
			buildSizeT(loc, lp.target),
			ir.Variable.Storage.Function,
			format("%si", fs.block.myScope.nestedDepth),
			buildConstantSizeT(loc, lp.target, 0)
		);
		assert(keyVar.type !is null);
		assert(valVar.type !is null);
		assert(indexVar.type !is null);
		fs.initVars ~= indexVar;

		// i < aa.keys.length
		auto index = buildExpReference(loc, indexVar, indexVar.name);
		auto len = buildAACall(lp.aaGetLength, indexVar.type);
		fs.test = buildBinOp(loc, ir.BinOp.Op.Less, index, len);

		// k = aa.keys[i]
		auto keys = buildAACall(lp.aaGetKeys, buildArrayTypeSmart(loc, keyVar.type));
		auto rh   = buildIndex(loc, keys, buildExpReference(loc, indexVar, indexVar.name));
		fs.block.statements = buildExpStat(loc, buildAssign(loc, keyVar, rh)) ~ fs.block.statements;

		// v = aa.exps[i]
		auto vals = buildAACall(lp.aaGetValues, buildArrayTypeSmart(loc, valVar.type));
		auto rh2  = buildIndex(loc, vals, buildExpReference(loc, indexVar, indexVar.name));
		fs.block.statements = buildExpStat(loc, buildAssign(loc, valVar, rh2)) ~ fs.block.statements;

		// i++
		fs.increments ~= buildIncrement(loc, buildExpReference(loc, indexVar, indexVar.name));

		return fs;
	}

	throw panic(loc, "expected foreach aggregate type");
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
		auto sa = buildStaticArrayTypeSmart(exp.loc, al.exps.length, arr.base);
		auto sexp = buildInternalStaticArrayLiteralSmart(exp.loc, sa, al.exps);
		exp = buildSlice(exp.loc, sexp);
	} else if (!isScope || !isBaseConst || !isExpsBackend) {
		auto sexp = buildInternalArrayLiteralSmart(al.loc, at, al.exps);
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
void lowerBuiltin(LanguagePass lp, ir.Scope current, ref ir.Exp exp, ir.BuiltinExp builtin)
{
	auto loc = exp.loc;
	final switch (builtin.kind) with (ir.BuiltinExp.Kind) {
	case ArrayPtr:
	case ArrayLength:
		break;
	case ArrayDup:
		if (builtin.children.length != 3) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		auto sexp = buildStatementExp(loc);
		auto type = builtin.type;
		auto asStatic = cast(ir.StaticArrayType)realType(type);
		ir.Exp value = builtin.children[0];
		value = buildSlice(loc, value, []);
		auto valueVar = buildVariableAnonSmart(loc, current, sexp, type, value);
		value = buildExpReference(loc, valueVar, valueVar.name);

		auto startCast = buildCastSmart(loc, buildSizeT(loc, lp.target), builtin.children[1]);
		auto startVar = buildVariableAnonSmart(loc, current, sexp, buildSizeT(loc, lp.target), startCast);
		auto start = buildExpReference(loc, startVar, startVar.name);
		auto endCast = buildCastSmart(loc, buildSizeT(loc, lp.target), builtin.children[2]);
		auto endVar = buildVariableAnonSmart(loc, current, sexp, buildSizeT(loc, lp.target), endCast);
		auto end = buildExpReference(loc, endVar, endVar.name);


		auto length = buildSub(loc, end, start);
		auto newExp = buildNewSmart(loc, type, length);
		auto var = buildVariableAnonSmart(loc, current, sexp, type, newExp);
		auto evar = buildExpReference(loc, var, var.name);
		auto sliceL = buildSlice(loc, evar, copyExp(start), copyExp(end));
		auto sliceR = buildSlice(loc, value, copyExp(start), copyExp(end));

		sexp.exp = buildAssign(loc, sliceL, sliceR);
		exp = sexp;
		break;
	case AALength:
		if (builtin.children.length != 1) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCall(exp.loc, lp.aaGetLength, builtin.children);
		break;
	case AAKeys:
		if (builtin.children.length != 1) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCastSmart(exp.loc, builtin.type,
		                     buildCall(exp.loc, lp.aaGetKeys, builtin.children));
		break;
	case AAValues:
		if (builtin.children.length != 1) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCastSmart(exp.loc, builtin.type,
		                     buildCall(exp.loc, lp.aaGetValues, builtin.children));
		break;
	case AARehash:
		if (builtin.children.length != 1) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCall(exp.loc, lp.aaRehash, builtin.children);
		break;
	case AAGet:
		if (builtin.children.length != 3) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		auto aa = cast(ir.AAType)realType(getExpType(builtin.children[0]));
		if (aa is null) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		// Value* ptr = cast(Value*)vrt_aa_in_binop_*(aa, key);
		// Value val = <default>;
		auto sexp = buildStatementExp(loc);
		ir.Function rtFn;
		if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
			rtFn = lp.aaInBinopPrimitive;
		} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
			rtFn = lp.aaInBinopArray;
		} else {
			rtFn = lp.aaInBinopPtr;
		}
		builtin.children[1] = lowerAAKeyCast(loc, lp, getModuleFromScope(loc, current),
			current, builtin.children[1], aa);
		auto ptr = buildVariableSmart(loc, buildPtrSmart(loc, aa.value), ir.Variable.Storage.Function,
			"ptr");
		auto val = buildVariableSmart(loc, aa.value, ir.Variable.Storage.Function, "val");
		ptr.assign = buildCall(loc, rtFn, [builtin.children[0], builtin.children[1]]);
		ptr.assign = buildCastSmart(loc, buildPtrSmart(loc, aa.value), ptr.assign);
		val.assign = buildCastSmart(loc, aa.value, builtin.children[2]);
		sexp.statements ~= ptr;
		sexp.statements ~= val;
		// if (ptr !is null) { val = *ptr; }
		auto assign = buildExpStat(loc, buildAssign(loc, buildExpReference(loc, val, val.name),
			buildDeref(loc, buildExpReference(loc, ptr, ptr.name))));
		auto thenStat = buildBlockStat(loc, null, current, assign);
		auto cond = buildBinOp(loc, ir.BinOp.Op.NotIs, buildExpReference(loc, ptr, ptr.name),
			buildConstantNull(loc, buildPtrSmart(loc, aa.value)));
		auto ifStat = buildIfStat(loc, cond, thenStat);
		sexp.statements ~= ifStat;
		sexp.exp = buildExpReference(loc, val, val.name);
		exp = sexp;
		break;
	case AARemove:
		if (builtin.children.length != 2) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		auto aa = cast(ir.AAType)realType(getExpType(builtin.children[0]));
		if (aa is null) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		ir.Function rtfn;
		builtin.children[1] = lowerAAKeyCast(loc, lp, getModuleFromScope(loc, current),
			current, builtin.children[1], aa);
		if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
			rtfn = lp.aaDeletePrimitive;
		} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
			rtfn = lp.aaDeleteArray;
		} else {
			rtfn = lp.aaDeletePtr;
		}
		exp = buildCall(exp.loc, rtfn, builtin.children);
		break;
	case AAIn:
		if (builtin.children.length != 2) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		auto aa = cast(ir.AAType)realType(getExpType(builtin.children[0]));
		if (aa is null) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		bool keyIsArray = isArray(realType(aa.key));
		ir.Function rtfn;
		builtin.children[1] = lowerAAKeyCast(loc, lp, getModuleFromScope(loc, current),
			current, builtin.children[1], aa);
		if (aa.key.nodeType == ir.NodeType.PrimitiveType) {
			rtfn = lp.aaInBinopPrimitive;
		} else if (aa.key.nodeType == ir.NodeType.ArrayType) {
			rtfn = lp.aaInBinopArray;
		} else {
			rtfn = lp.aaInBinopPtr;
		}
		exp = buildCall(exp.loc, rtfn, builtin.children);
		exp = buildCast(loc, builtin.type, exp);
		break;
	case AADup:
		if (builtin.children.length != 1) {
			throw panic(exp.loc, "malformed BuiltinExp.");
		}
		exp = buildCall(loc, lp.aaDup, builtin.children);
		exp = buildCastSmart(loc, builtin.type, exp);
		break;
	case Classinfo:
		panicAssert(exp, builtin.children.length == 1);
		auto iface = cast(ir._Interface)realType(getExpType(builtin.children[0]));
		auto ti = buildPtrSmart(loc, buildPtrSmart(loc, buildArrayType(loc, copyTypeSmart(loc, lp.tiClassInfo))));
		auto sexp = buildStatementExp(loc);
		ir.Exp ptr = buildCastToVoidPtr(loc, builtin.children[0]);
		if (iface !is null) {
			/* We need the class vtable. Each interface instance holds the
			 * amount it's set forward from the beginning of the class one,
			 * as the first entry in the interface layout table,
			 * so we just do `**cast(size_t**)cast(void*)iface` to get at it.
			 * Then we subtract that value from the pointer.
			 */
			auto offset = buildDeref(loc, buildDeref(loc,
				buildCastSmart(loc, buildPtrSmart(loc, buildPtrSmart(loc, buildSizeT(loc, lp.target))), copyExp(loc, ptr))));
			ptr = buildSub(loc, ptr, offset);
		}
		auto tinfos = buildDeref(loc, buildDeref(loc, buildCastSmart(loc, ti, ptr)));
		auto tvar = buildVariableAnonSmart(loc, current, sexp,
		                                   buildArrayType(loc,
		                                   copyTypeSmart(loc, lp.tiClassInfo)), tinfos);
		ir.Exp tlen = buildArrayLength(loc, lp.target, buildExpReference(loc, tvar, tvar.name));
		tlen = buildSub(loc, tlen, buildConstantSizeT(loc, lp.target, 1));
		sexp.exp = buildIndex(loc, buildExpReference(loc, tvar, tvar.name), tlen);
		exp = buildCastSmart(loc, lp.tiClassInfo, sexp);
		break;
	case PODCtor:
		panicAssert(exp, builtin.children.length == 1);
		panicAssert(exp, builtin.functions.length == 1);
		lowerStructUnionConstructor(lp, current, exp, builtin);
		break;
	case VaStart:
		panicAssert(exp, builtin.children.length == 2);
		builtin.children[1] = buildArrayPtr(loc, buildVoid(loc), builtin.children[1]);
		exp = buildAssign(loc, buildDeref(loc, buildAddrOf(builtin.children[0])), builtin.children[1]);
		break;
	case VaEnd:
		panicAssert(exp, builtin.children.length == 1);
		exp = buildAssign(loc, buildDeref(loc, buildAddrOf(builtin.children[0])), buildConstantNull(loc, buildVoidPtr(loc)));
		break;
	case VaArg:
		panicAssert(exp, builtin.children.length == 1);
		auto vaexp = cast(ir.VaArgExp)builtin.children[0];
		panicAssert(exp, vaexp !is null);
		exp = lowerVaArg(vaexp.loc, lp, vaexp);
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

	auto ptrToPtr = buildVariableSmart(loc, buildPtrSmart(loc, buildVoidPtr(loc)), ir.Variable.Storage.Function, "ptrToPtr");
	ptrToPtr.assign = buildAddrOf(loc, vaexp.arg);
	sexp.statements ~= ptrToPtr;

	auto cpy = buildVariableSmart(loc, buildVoidPtr(loc), ir.Variable.Storage.Function, "cpy");
	cpy.assign = buildDeref(loc, ptrToPtr);
	sexp.statements ~= cpy;

	auto vlderef = buildDeref(loc, ptrToPtr);
	auto tid = buildTypeidSmart(loc, vaexp.type);
	auto sz = getSizeOf(loc, lp, vaexp.type);
	auto assign = buildAddAssign(loc, vlderef, sz);
	buildExpStat(loc, sexp, assign);

	auto ptr = buildPtrSmart(loc, vaexp.type);
	auto _cast = buildCastSmart(loc, ptr, buildExpReference(loc, cpy));
	auto deref = buildDeref(loc, _cast);
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
	exp = buildCreateDelegate(exp.loc, buildExpReference(np.loc, np, np.name), eref);
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
                  ref ir.Exp exp, ir.Function parentFunc, ir.Postfix postfix)
{
	switch(postfix.op) {
	case ir.Postfix.Op.Index:
		lowerIndex(lp, current, thisModule, exp, postfix);
		break;
	default:
		break;
	}
	ir._Interface iface;
	if (isInterfacePointer(lp, postfix, current, iface)) {
		assert(iface !is null);
		auto cpostfix = cast(ir.Postfix) postfix.child;  // TODO: Calling returned interfaces directly.
		if (cpostfix is null || cpostfix.memberFunction is null) {
			throw makeExpected(exp.loc, "interface");
		}
		auto func = cast(ir.Function) cpostfix.memberFunction.decl;
		if (func is null) {
			throw makeExpected(exp.loc, "method");
		}
		auto loc = exp.loc;
		auto agg = cast(ir._Interface)realType(getExpType(cpostfix.child));
		panicAssert(postfix, agg !is null);
		auto store = lookupInGivenScopeOnly(lp, agg.layoutStruct.myScope, loc, "__offset");
		auto fstore = lookupInGivenScopeOnly(lp, agg.layoutStruct.myScope, loc, mangle(null, func));
		panicAssert(postfix, store !is null);
		panicAssert(postfix, fstore !is null);
		auto var = cast(ir.Variable)store.node;
		auto fvar = cast(ir.Variable)fstore.node;
		panicAssert(postfix, var !is null);
		panicAssert(postfix, fvar !is null);
		auto handle = buildCastToVoidPtr(loc, buildSub(loc, buildCastSmart(loc,
		                                 buildPtrSmart(loc, buildUbyte(loc)),
		                                 copyExp(cpostfix.child)),
		                                 buildAccessExp(loc, buildDeref(loc,
		                                 copyExp(cpostfix.child)), var)));
		exp = buildCall(loc, buildAccessExp(loc, buildDeref(loc, cpostfix.child),
		                                  fvar), handle ~ postfix.arguments);
	}
	lowerVarargCall(lp, current, postfix, parentFunc, exp);
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
				argexp = buildCastSmart(loc, buildDouble(loc), argexp);
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
		throw makeWrongNumberOfArguments(postfix, callNumArgs, funcNumArgs);
	}
	auto passSlice = postfix.arguments[0 .. funcNumArgs];
	auto varArgsSlice = postfix.arguments[funcNumArgs .. $];

	auto tinfoClass = lp.tiTypeInfo;
	auto tr = buildTypeReference(postfix.loc, tinfoClass, tinfoClass.name);
	tr.loc = postfix.loc;

	auto sexp = buildStatementExp(loc);
	auto numVarArgs = varArgsSlice.length;
	ir.Exp idsSlice, argsSlice;

	if (numVarArgs > 0) {
		auto idsType = buildStaticArrayTypeSmart(loc, varArgsSlice.length, tr);
		auto argsType = buildStaticArrayTypeSmart(loc, 0, buildVoid(loc));
		auto ids = buildVariableAnonSmartAtTop(loc, func._body, idsType, null);
		auto args = buildVariableAnonSmartAtTop(loc, func._body, argsType, null);

		int[] sizes;
		size_t totalSize;
		ir.Type[] types;
		foreach (i, _exp; varArgsSlice) {
			auto etype = getExpType(_exp);
			if (lp.beMoreLikeD &&
					realType(etype).nodeType == ir.NodeType.Struct) {
				warning(_exp.loc, "passing struct to var-arg function.");
			}

			auto ididx = buildIndex(loc, buildExpReference(loc, ids, ids.name), buildConstantSizeT(loc, lp.target, i));
			buildExpStat(loc, sexp, buildAssign(loc, ididx, buildTypeidSmart(loc, lp, etype)));

			// *(cast(T*)arr.ptr + totalSize) = exp;
			auto argl = buildDeref(loc, buildCastSmart(loc, buildPtrSmart(loc, etype),
						buildAdd(loc, buildArrayPtr(loc, buildVoid(loc),
								buildExpReference(loc, args, args.name)), buildConstantSizeT(loc, lp.target, totalSize))));

			buildExpStat(loc, sexp, buildAssign(loc, argl, _exp));

			totalSize += size(lp.target, etype);
		}

		(cast(ir.StaticArrayType)args.type).length = totalSize;
		idsSlice = buildSlice(loc, buildExpReference(loc, ids, ids.name));
		argsSlice = buildSlice(loc, buildExpReference(loc, args, args.name));
	} else {
		auto idsType = buildArrayType(loc, tr);
		auto argsType = buildArrayType(loc, buildVoid(loc));
		idsSlice = buildArrayLiteralSmart(loc, idsType, []);
		argsSlice = buildArrayLiteralSmart(loc, argsType, []);
	}

	postfix.arguments = passSlice ~ idsSlice ~ argsSlice;
	sexp.exp = postfix;
	exp = sexp;
}

void lowerGlobalAALiteral(LanguagePass lp, ir.Scope current, ir.Module mod, ir.Variable var)
{
	auto loc = var.loc;
	auto gctor = buildGlobalConstructor(loc, mod.children, current, "__ctor");
	ir.BinOp assign = buildAssign(loc, var, var.assign);
	buildExpStat(loc, gctor._body, assign);
	var.assign = null;
	buildReturnStat(loc, gctor._body);
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
             ir.AssocArray assocArray)
{
	auto loc = exp.loc;
	auto aa = cast(ir.AAType)getExpType(exp);
	assert(aa !is null);

	auto statExp = buildStatementExp(loc);
	auto aaNewFn = lp.aaNew;

	auto bs = cast(ir.BlockStatement)current.node;
	if (bs is null) {
		auto func = cast(ir.Function)current.node;
		if (func !is null) {
			bs = func._body;
		}
	}
	panicAssert(exp, bs !is null);

	auto var = buildVariableAnonSmart(loc, bs, statExp,
		copyTypeSmart(loc, aa), buildCall(loc, aaNewFn, [
			cast(ir.Exp)buildTypeidSmart(loc, lp, aa.value),
			cast(ir.Exp)buildTypeidSmart(loc, lp, aa.key)
		], aaNewFn.name)
	);

	foreach (pair; assocArray.pairs) {
		auto key = buildVariableAnonSmart(loc, bs, statExp,
			copyTypeSmart(loc, aa.key), pair.key
		);

		auto value = buildVariableAnonSmart(loc, bs, statExp,
			copyTypeSmart(loc, aa.value), pair.value
		);

		lowerAAInsert(loc, lp, thisModule, current, statExp,
			 aa, var, buildExpReference(loc, key), buildExpReference(loc, value),
			 false, false
		);
	}

	statExp.exp = buildExpReference(loc, var);
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
	auto sexp = buildStatementExp(loc);
	auto svar = buildVariableAnonSmart(loc, current, sexp, agg, null);
	auto args = buildCast(loc, buildVoidPtr(loc), buildAddrOf(loc,
		buildExpReference(loc, svar, svar.name))) ~ postfix.arguments;
	auto ctorCall = buildCall(loc, ctor, args);

	buildExpStat(loc, sexp, ctorCall);
	sexp.exp = buildExpReference(loc, svar, svar.name);
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
	auto memset = buildExpReference(loc, llvmMemset, llvmMemset.name);
	auto ptr = buildCastToVoidPtr(loc, buildAddrOf(loc, buildExpReference(loc, var, var.name)));
	auto zero = buildConstantUbyte(loc, 0);
	auto size = buildConstantSizeT(loc, lp.target, s);
	auto alignment = buildConstantInt(loc, 0);
	auto isVolatile = buildConstantBool(loc, false);
	return buildCall(loc, memset, [ptr, zero, size, alignment, isVolatile]);
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
		bs.statements = bs.statements[0 .. i+1] ~ buildExpStat(exp.loc, exp) ~ bs.statements[i+1 .. $];
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
				acceptExp(asPostfix.child, this);
				acceptExp(asPostfix.arguments[0], this);
				acceptExp(binOp.right, this);

				if (binOp.op == ir.BinOp.Op.Assign) {
					lowerAssignAA(lp, current, thisModule, exp, binOp, asPostfix,
								  cast(ir.AAType)leftType);
				} else {
					lowerOpAssignAA(lp, current, thisModule, exp, binOp, asPostfix,
									cast(ir.AAType)leftType);
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
			lowerAssign(lp, thisModule, exp, binOp);
			break;
		case ir.BinOp.Op.Cat:
			lowerCat(lp, thisModule, exp, binOp);
			break;
		case ir.BinOp.Op.CatAssign:
			lowerCatAssign(lp, thisModule, exp, binOp);
			break;
		case ir.BinOp.Op.NotEqual:
		case ir.BinOp.Op.Equal:
			lowerEqual(lp, thisModule, exp, binOp);
			break;
		default:
			break;
		}
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.BuiltinExp builtin)
	{
		lowerBuiltin(lp, current, exp, builtin);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.ArrayLiteral al)
	{
		if (al.exps.length > 0 && functionStack.length > 0) {
			lowerArrayLiteral(lp, current, exp, al);
		}
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.AssocArray assocArray)
	{
		lowerAA(lp, current, thisModule, exp, assocArray);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Unary uexp)
	{
		lowerInterfaceCast(exp.loc, lp, current, uexp, exp);
		if (functionStack.length > 0) {
			lowerArrayCast(exp.loc, lp, current, uexp, exp);
		}

		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.Postfix postfix)
	{
		lowerPostfix(lp, current, thisModule, exp,
			functionStack.length == 0 ? null : functionStack[$-1], postfix);
		return Continue;
	}

	override Status leave(ref ir.Exp exp, ir.PropertyExp prop)
	{
		lowerProperty(lp, exp, prop);
		auto pfix = cast(ir.Postfix)exp;
		if (pfix !is null) {
			lowerPostfix(lp, current, thisModule, exp,
				functionStack.length == 0 ? null : functionStack[$-1], pfix);
		}
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.StructLiteral literal)
	{
		if (functionStack.length == 0) {
			// Global struct literals can use LLVM's native handling.
			return Continue;
		}
		lowerStructLiteral(current, exp, literal);
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
		lowerStructLookupViaFunctionCall(lp, current, exp, ae, type);
		return Continue;
	}

	override Status visit(ref ir.Exp exp, ir.ExpReference eref)
	{
		ir.Function currentFunc = functionStack.length == 0 ? null : functionStack[$-1];
		bool replaced = replaceNested(lp, exp, eref, currentFunc);
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
		lowerExpReference(functionStack, exp, eref, func);
		return Continue;
	}

	override Status enter(ref ir.Exp exp, ir.StringImport simport)
	{
		lowerStringImport(lp.driver, exp, simport);
		return Continue;
	}
}
