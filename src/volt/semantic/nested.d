 // Copyright © 2013, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.semantic.nested;

import std.algorithm : remove;
import std.conv : to;

import volt.errors;
import ir = volt.ir.ir;
import volt.ir.copy;
import volt.ir.util;
import volt.interfaces;
import volt.visitor.manip;
import volt.visitor.visitor;
import volt.semantic.lookup;
import volt.semantic.gatherer;
import volt.semantic.context;

void emitNestedStructs(ir.Function parentFunction, ir.BlockStatement bs)
{
	for (size_t i = 0; i < bs.statements.length; ++i) {
		auto fn = cast(ir.Function) bs.statements[i];
		if (fn is null) {
			continue;
		}
		if (fn.oldname.length == 0) {
			foreach (existingFn; parentFunction.nestedFunctions) {
				if (fn.name == existingFn.oldname) {
					throw makeCannotOverloadNested(fn, fn);
				}
			}
			parentFunction.nestedFunctions ~= fn;
			fn.oldname = fn.name;
			fn.name = fn.name ~ to!string(parentFunction.nestedFunctions.length - 1);
		}
		if (parentFunction.nestStruct is null) {
			parentFunction.nestStruct = createAndAddNestedStruct(parentFunction, bs);
		}
		emitNestedStructs(parentFunction, fn._body);
	}
}

ir.Struct createAndAddNestedStruct(ir.Function fn, ir.BlockStatement bs)
{
	auto s = buildStruct(fn.location, "__Nested", []);
	auto decl = buildVariable(fn.location, buildTypeReference(s.location, s, "__Nested"), ir.Variable.Storage.Function, "__nested");
	fn.nestedVariable = decl;
	bs.statements = s ~ (decl ~ bs.statements);
	return s;
}

bool replaceNested(ref ir.Exp exp, ir.ExpReference eref, ir.Variable nestParam)
{
	if (eref.doNotRewriteAsNestedLookup) {
		return false;
	}
	string name;

	auto fp = cast(ir.FunctionParam) eref.decl;
	if (fp is null || !fp.hasBeenNested) {
		auto var = cast(ir.Variable) eref.decl;
		if (var is null || var.storage != ir.Variable.Storage.Nested) { 
			return false;
		} else {
			name = var.name;
		}
	} else {
		name = fp.name;
	}
	assert(name.length > 0);

	if (nestParam is null) {
		return false;
	}
	exp = buildAccess(exp.location, buildExpReference(nestParam.location, nestParam, nestParam.name), name);
	return true;
}

void insertBinOpAssignsForNestedVariableAssigns(ir.BlockStatement bs)
{
	for (size_t i = 0; i < bs.statements.length; ++i) {
		auto var = cast(ir.Variable) bs.statements[i];
		if (var is null || var.storage != ir.Variable.Storage.Nested) {
			continue;
		}
		if (var.assign is null) {
			bs.statements = remove(bs.statements, i--);
		} else {
			auto assign = buildAssign(var.location, buildExpReference(var.location, var, var.name), var.assign);
			bs.statements[i] = buildExpStat(assign.location, assign);
		}
	}
}

void tagNestedVariables(Context ctx, ir.Variable var, ir.Store store, ref ir.Exp e)
{
	if (!ctx.isFunction || ctx.currentFunction.nestStruct is null) {
		return;
	}
	if (ctx.current.nestedDepth > store.parent.nestedDepth) {
		assert(ctx.currentFunction.nestStruct !is null);
		if (var.storage != ir.Variable.Storage.Field && var.storage != ir.Variable.Storage.Nested) {
			addVarToStructSmart(ctx.currentFunction.nestStruct, var);
			var.storage = ir.Variable.Storage.Nested;
		} else if (var.storage == ir.Variable.Storage.Field) {
			if (ctx.currentFunction.nestedHiddenParameter is null) {
				return;
			}
			auto nref = buildExpReference(var.location, ctx.currentFunction.nestedHiddenParameter, ctx.currentFunction.nestedHiddenParameter.name);
			auto a = buildAccess(var.location, nref, "this");
			e = buildAccess(a.location, a, var.name);
		}
		if (var.storage != ir.Variable.Storage.Field) {
			var.storage = ir.Variable.Storage.Nested;
		}
	}
}
