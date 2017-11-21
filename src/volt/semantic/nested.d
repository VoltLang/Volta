/*#D*/
// Copyright © 2013-2015, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.nested;

import watt.conv : toString;
import watt.text.format : format;

import ir = volta.ir;
import volta.util.copy;
import volta.util.util;

import volt.errors;

import volt.interfaces;
import volt.semantic.util;
import volt.semantic.lookup : getModuleFromScope, lookupInGivenScopeOnly;
import volt.semantic.context;
import volt.semantic.classify : isNested, realType;
import volta.ir.location : Location;

/*!
 * This module contains utility functions for dealing with nested functions;
 * 'functions within functions'.
 *
 * LLVM (and most other potential backend tooling) generates in top level functions.
 * That means, when the user writes:
 *
 *     int getX() {
 *         int x = 32;
 *         void doubleX() { x *= 2; }
 *         return x;
 *     }
 *
 * A fair amount of magic has to take place to create a shared context that contains
 * x, give it to doubleX, and rewrite every reference appropriately so nothing explodes,
 * and everything works as expected. That's what the functions in this module help with.
 *
 * Not that nested functions preceded by 'global', i.e. ir.Function.Kind.GlobalNested,
 * are not 'truly' nested -- the above rewriting doesn't take place, and trying to access
 * something in the parent function will generate an error.
 */

/*
 *
 * Functions to be called by extyper.
 *
 */

/*!
 * Tag referenced Variables as nested if appropriate.
 *
 * If an identifier references a Variable, and that variables parent scope is higher
 * than the current -- that is to say, the reference is in a nested function -- then
 * that Variable's storage will be tagged as Nested. Otherwise, nothing happens.
 *
 * Params:
 *   loc: If an error is generated, this location will be what it points at.
 *   ctx: The extyper Context.
 *   var: The Variable that the reference refers to.
 *   store: The Store that var was found in.
 */
void nestExtyperTagVariable(ref in Location loc, Context ctx, ir.Variable var, ir.Store store)
{
	if (!ctx.isFunction) {
		return;
	}

	if (ctx.current.nestedDepth <= store.parent.nestedDepth) {
		return;
	}

	if (var.storage != ir.Variable.Storage.Field &&
	    !isNested(var.storage)) {
	    if (ctx.currentFunction.kind != ir.Function.Kind.Nested) {
			throw makeNonNestedAccess(/*#ref*/loc, var);
	    }
		// If we're tagging a global variable, just ignore it.
		if (var.storage == ir.Variable.Storage.Local ||
		    var.storage == ir.Variable.Storage.Global) {
			return;
		}

		var.storage = ir.Variable.Storage.Nested;
	}
}

/*!
 * Add a child function to the list of nested functions in a parent function.
 *
 * Params:
 *   parent: The parent function.
 *   func: The child function.
 */
void nestExtyperFunction(ir.Function parent, ir.Function func)
{
	parent.nestedFunctions ~= func;
}


/*
 *
 * Functions to be called by the lowerer.
 *
 */

/*!
 * Add the context struct to a nested function.
 *
 * Params:
 *   lp: The LanguagePass.
 *   parent: The parent function that the nested function resides in.
 *   func: The nested function to add the context struct to.
 */
void nestLowererFunction(LanguagePass lp, ir.Function parent, ir.Function func)
{
	if (parent is null) {
		if (func.nestedFunctions.length > 0) {
			doParent(lp, func);
		}
		return;
	}

	assert(parent.nestStruct !is null);
	assert(func.nestedHiddenParameter is null);

	auto ns = parent.nestStruct;

	panicAssert(func, ns !is null);

	auto tr = buildTypeReference(/*#ref*/ns.loc, ns, "__Nested");
	auto decl = buildVariable(/*#ref*/func.loc, tr, ir.Variable.Storage.Function, "__nested");
	decl.isResolved = true;
	decl.specialInitValue = true;

	// XXX: Note __nested is not added to any scope.
	// XXX: Instead make sure that nestedHiddenParameter is visited (and as such visited)

	func.nestedHiddenParameter = decl;
	func.nestedVariable = decl;
	func.nestStruct = ns;
	func.type.hiddenParameter = true;
	func._body.statements = decl ~ func._body.statements;
}

/*!
 * Replace nested Variable declarations with assign expressions.
 *
 * Because all nested Variables will be transformed to exist on the nested struct,
 * every declaration needs to be turned into an assignment, to ensure the values are
 * what they should be.
 *
 * Params:
 *   lp: The LanguagePass.
 *   bs: The BlockStatement to scan for Variables.
 */
void insertBinOpAssignsForNestedVariableAssigns(LanguagePass lp, ir.BlockStatement bs)
{
	for (size_t i = 0; i < bs.statements.length; ++i) {
		auto var = cast(ir.Variable) bs.statements[i];
		if (var is null ||
		    !var.storage.isNested()) {
			continue;
		}

		ir.Exp value;
		if (var.assign is null) {
			value = getDefaultInit(/*#ref*/var.loc, lp, var.type);
		} else {
			value = var.assign;
		}

		auto eref = buildExpReference(/*#ref*/var.loc, var, var.name);
		auto assign = buildAssign(/*#ref*/var.loc, eref, value);
		bs.statements[i] = buildExpStat(/*#ref*/assign.loc, assign);
	}
}

/*!
 * If the current function is a nested one, replace a given ExpReference with an expression
 * that will retrieve the correct value from the nested struct.
 *
 * Params:
 *   lp: The LanguagePass.
 *   exp: The expression where the reference took place. May be rewritten.
 *   eref: The ExpReference to check.
 *   currentFunction: The current function when eref was found.
 */
bool replaceNested(LanguagePass lp, ref ir.Exp exp, ir.ExpReference eref, ir.Function currentFunction)
{
	if (eref.doNotRewriteAsNestedLookup) {
		return false;
	}
	if (currentFunction is null) {
		return false;
	}
	auto nestVar = currentFunction.nestedVariable;
	auto nestStruct = currentFunction.nestStruct;
	if (nestStruct is null) {
		return false;
	}
	assert(nestVar !is null);

	string name;
	ir.Type type;
	bool shouldDeref;

	switch (eref.decl.nodeType) with (ir.NodeType) {
	case FunctionParam:
		auto fp = cast(ir.FunctionParam) eref.decl;
		if (!fp.hasBeenNested) {
			return false;
		}
		name = fp.name;
		type = fp.type;

		shouldDeref = fp.func.type.isArgRef[fp.index] ||
		              fp.func.type.isArgOut[fp.index];

		exp = buildDeref(/*#ref*/exp.loc, exp);
		break;
	case Variable:
		auto var = cast(ir.Variable) eref.decl;
		assert(var.storage != ir.Variable.Storage.Field);

		if (var.name != "this" && !var.storage.isNested()) {
			return false;
		}

		auto store = lookupInGivenScopeOnly(
				lp, nestStruct.myScope,
				/*#ref*/exp.loc, var.name);
		if (store is null) {
			assert(var.name != "this");
			addVarToStructSmart(lp.errSink, nestStruct, var);
		}
		name = var.name;
		type = var.type;
		if (var.name == "this") {
			auto nt = realType(type).nodeType;
			shouldDeref = (nt == ir.NodeType.Struct || nt == ir.NodeType.Union);
		}
		break;
	default:
		return false;
	}

	assert(name.length > 0);

	auto store = lookupInGivenScopeOnly(lp, nestStruct.myScope, /*#ref*/exp.loc, name);
	panicAssert(eref, store !is null);
	auto v = cast(ir.Variable) store.node;
	panicAssert(eref, v !is null);

	auto nestEref = buildExpReference(/*#ref*/nestVar.loc, nestVar, nestVar.name);
	exp = buildAccessExp(/*#ref*/exp.loc, nestEref, v);
	if (shouldDeref) {
		exp = buildDeref(/*#ref*/exp.loc, exp);
	}
	return true;
}



/*
 *
 * Private
 *
 */

private:

/*!
 * Utility function to be called on Functions with a function nested in them.
 * Adds the struct, actualizes it, adds parameters, etc.
 */
void doParent(LanguagePass lp, ir.Function parent)
{
	auto ns = parent.nestStruct;
	if (ns !is null) {
		return;
	}

	createAndAddNestedStruct(parent);
	assert(parent.nestStruct !is null);
	lp.actualize(parent.nestStruct);

	handleNestedThis(lp.errSink, parent, parent._body);
	handleNestedParams(lp.errSink, parent, parent._body);
}

/*!
 * Create the nested struct and a declaration pointing to it.
 * Populates the nestedVariable and nestStruct members of a Function.
 */
ir.Struct createAndAddNestedStruct(ir.Function func)
{
	auto bs = func._body;
	auto id = getModuleFromScope(/*#ref*/func.loc, func.myScope).getId();
	auto s = buildStruct(/*#ref*/func.loc, format("__Nested%s", id));
	s.myScope = new ir.Scope(bs.myScope, s, s.name, bs.myScope.nestedDepth);
	auto tref = buildTypeReference(/*#ref*/s.loc, s, "__Nested");
	auto decl = buildVariable(
		/*#ref*/func.loc, tref, ir.Variable.Storage.Function, "__nested");
	decl.isResolved = true;
	func.nestedVariable = decl;
	func.nestStruct = s;
	bs.statements = s ~ (decl ~ bs.statements);
	return s;
}

/*!
 * Given a nested function func, add its parameters to the nested
 * struct and insert statements after the nested declaration.
 */
void handleNestedParams(ErrorSink errSink, ir.Function func, ir.BlockStatement bs)
{
	auto np = func.nestedVariable;
	auto ns = func.nestStruct;
	if (np is null || ns is null) {
		return;
	}

	// Don't add parameters for nested functions.
	if (func.kind == ir.Function.Kind.Nested) {
		return;
	}

	// This is needed for the parent function.
	size_t index;
	for (index = 0; index < bs.statements.length; ++index) {
		if (bs.statements[index] is np) {
			break;
		}
	}
	++index;

	if (index > bs.statements.length) {
		index = 0;  // We didn't find a usage, so put it at the start.
	}

	foreach (i, param; func.params) {
		if (!param.hasBeenNested) {
			param.hasBeenNested = true;

			auto type = param.type;
			bool refParam = func.type.isArgRef[i] || func.type.isArgOut[i];
			if (refParam) {
				type = buildPtrSmart(/*#ref*/param.loc, param.type);
			}
			auto name = param.name != "" ? param.name : format("__anonparam_%s", toString(index));
			auto var = buildVariableSmart(/*#ref*/param.loc, type, ir.Variable.Storage.Field, name);
			addVarToStructSmart(errSink, ns, var);
			// Insert an assignment of the param to the nest struct.

			auto l = buildAccessExp(/*#ref*/param.loc, buildExpReference(/*#ref*/np.loc, np, np.name), var);
			auto r = buildExpReference(/*#ref*/param.loc, param, name);
			r.doNotRewriteAsNestedLookup = true;
			ir.BinOp bop;
			if (!refParam) {
				bop = buildAssign(/*#ref*/l.loc, l, r);
			} else {
				bop = buildAssign(/*#ref*/l.loc, l, buildAddrOf(/*#ref*/r.loc, r));
			}
			bop.isInternalNestedAssign = true;
			ir.Node n = buildExpStat(/*#ref*/l.loc, bop);
			if (func.isNested()) {
				// Nested function.
				bs.statements = n ~ bs.statements;
			} else {
				// Parent function with nested children.
				bs.statements.insertInPlace(index++, n);
			}
		}
	}
}

/*!
 * Correct this references in nested functions.
 *
 * Rewrites them to refer to a this hosted on the nested struct.
 */
void handleNestedThis(ErrorSink errSink, ir.Function func, ir.BlockStatement bs)
{
	bs = func._body;
	auto np = func.nestedVariable;
	auto ns = func.nestStruct;
	if (np is null || ns is null) {
		return;
	}
	size_t index;
	for (index = 0; index < bs.statements.length; ++index) {
		if (bs.statements[index] is np) {
			break;
		}
	}
	if (++index >= bs.statements.length) {
		return;
	}
	if (func.thisHiddenParameter !is null) {
		auto nt = realType(func.thisHiddenParameter.type).nodeType;
		bool structOrUnion = nt == ir.NodeType.Struct || nt == ir.NodeType.Union;
		auto lc = bs.loc;

		ir.Variable cvar;
		if (structOrUnion) {
			auto tptr = buildPtrSmart(/*#ref*/lc, func.thisHiddenParameter.type);
			auto nvar = buildVariableSmart(/*#ref*/lc, tptr, ir.Variable.Storage.Field, "this");
			cvar = addVarToStructSmart(errSink, ns, nvar);
		} else {
			cvar = addVarToStructSmart(errSink, ns, func.thisHiddenParameter);
		}

		auto l = buildAccessExp(/*#ref*/func.loc,
			buildExpReference(/*#ref*/np.loc, np, np.name), cvar);

		auto tv = func.thisHiddenParameter;
		auto eref = buildExpReference(/*#ref*/bs.loc, tv, tv.name);
		eref.doNotRewriteAsNestedLookup = true;
		ir.Exp r = eref;
		if (structOrUnion) {
			r = buildAddrOf(/*#ref*/lc, eref);
		}
		ir.Node n = buildExpStat(/*#ref*/l.loc, buildAssign(/*#ref*/l.loc, l, r));
		bs.statements.insertInPlace(index, n);
	}
}
