// Copyright © 2013-2015, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.nested;

import watt.conv : toString;

import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;

import volt.errors;

import volt.interfaces;
import volt.semantic.util;
import volt.semantic.lookup : getModuleFromScope;
import volt.semantic.context;
import volt.semantic.classify : isNested;


void emitNestedStructs(ir.Function parentFunction, ir.BlockStatement bs, ref ir.Struct[] structs)
{
	for (size_t i = 0; i < bs.statements.length; ++i) {
		auto fn = cast(ir.Function) bs.statements[i];
		if (fn is null) {
			continue;
		}
		if (fn.suffix.length == 0) {
			foreach (existingFn; parentFunction.nestedFunctions) {
				if (fn.name == existingFn.oldname) {
					throw makeCannotOverloadNested(fn, fn);
				}
			}
			parentFunction.nestedFunctions ~= fn;
			fn.suffix = toString(getModuleFromScope(parentFunction.location, parentFunction._body.myScope).getId());
		}
		if (parentFunction.nestStruct is null) {
			parentFunction.nestStruct = createAndAddNestedStruct(parentFunction, parentFunction._body);
			structs ~= parentFunction.nestStruct;
		}
		emitNestedStructs(parentFunction, fn._body, structs);
	}
}

ir.Struct createAndAddNestedStruct(ir.Function fn, ir.BlockStatement bs)
{
	auto s = buildStruct(fn.location, "__Nested" ~ toString(cast(void*)fn), []);
	s.myScope = new ir.Scope(bs.myScope, s, s.name);
	auto decl = buildVariable(fn.location, buildTypeReference(s.location, s, "__Nested"), ir.Variable.Storage.Function, "__nested");
	decl.isResolved = true;
	fn.nestedVariable = decl;
	bs.statements = s ~ (decl ~ bs.statements);
	return s;
}

bool replaceNested(ref ir.Exp exp, ir.ExpReference eref, ir.Variable nestParam)
{
	if (eref.doNotRewriteAsNestedLookup) {
		return false;
	}
	if (nestParam is null) {
		return false;
	}

	string name;
	ir.Type type;
	ir.FunctionParam fp;

	switch (eref.decl.nodeType) with (ir.NodeType) {
	case FunctionParam:
		fp = cast(ir.FunctionParam) eref.decl;
		if (!fp.hasBeenNested) {
			return false;
		}
		name = fp.name;
		type = fp.type;
		break;
	case Variable:
		auto var = cast(ir.Variable) eref.decl;
		if (!var.storage.isNested()) {
			return false;
		}
		name = var.name;
		type = var.type;
		break;
	default:
		return false;
	}

	assert(name.length > 0);

	exp = buildAccess(exp.location, buildExpReference(nestParam.location, nestParam, nestParam.name), name);
	if (fp !is null &&
	    (fp.fn.type.isArgRef[fp.index] ||
	     fp.fn.type.isArgOut[fp.index])) {
		exp = buildDeref(exp.location, exp);
	}
	return true;
}

void insertBinOpAssignsForNestedVariableAssigns(LanguagePass lp, ir.BlockStatement bs)
{
	for (size_t i = 0; i < bs.statements.length; ++i) {
		auto var = cast(ir.Variable) bs.statements[i];
		if (var is null ||
		    !var.storage.isNested()) {
			continue;
		}

		version (none) {
			bs.statements = bs.statements[0 .. i] ~ bs.statements[i + 1 .. $];
			i--;
		}

		ir.Exp value;
		if (var.assign is null) {
			value = getDefaultInit(var.location, lp, var.type);
		} else {
			value = var.assign;
		}

		auto eref = buildExpReference(var.location, var, var.name);
		auto assign = buildAssign(var.location, eref, value);
		bs.statements[i] = buildExpStat(assign.location, assign);
	}
}

void tagNestedVariables(Context ctx, ir.Variable var, ir.Store store, ref ir.Exp e)
{
	if (!ctx.isFunction ||
	    ctx.currentFunction.nestStruct is null) {
		return;
	}

	if (ctx.current.nestedDepth <= store.parent.nestedDepth) {
		return;
	}

	assert(ctx.currentFunction.nestStruct !is null);
	if (var.storage != ir.Variable.Storage.Field &&
	    !isNested(var.storage)) {
		// If we're tagging a global variable, just ignore it.
		if (var.storage == ir.Variable.Storage.Local ||
		    var.storage == ir.Variable.Storage.Global) {
			return;
		}

		var.storage = ir.Variable.Storage.Nested;

		// Skip adding this variables to nested struct.
		if (var.name == "this") {
			return;
		}
		addVarToStructSmart(ctx.currentFunction.nestStruct, var);
	} else if (var.storage == ir.Variable.Storage.Field) {
		if (ctx.currentFunction.nestedHiddenParameter is null) {
			return;
		}
		auto nref = buildExpReference(var.location, ctx.currentFunction.nestedHiddenParameter, ctx.currentFunction.nestedHiddenParameter.name);
		auto a = buildAccess(var.location, nref, "this");
		e = buildAccess(a.location, a, var.name);
	}
}
