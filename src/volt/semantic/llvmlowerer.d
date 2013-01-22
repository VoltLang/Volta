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
	bool V_P64;
	Settings settings;
	ir.Module thisModule;

public:
	this(Settings settings)
	{
		this.settings = settings;
		this.V_P64 = settings.isVersionSet("V_P64");
	}

	override void transform(ir.Module m)
	{
		thisModule = m;
		accept(m, this);
	}

	override void close()
	{
	}

	override Status enter(ref ir.Exp exp, ir.BinOp binOp)
	{
		if (binOp.op != ir.BinOp.Type.Assign)
			return Continue;

		auto loc = binOp.location;
		auto asPostfix = cast(ir.Postfix)binOp.left;

		if (asPostfix is null || asPostfix.op != ir.Postfix.Op.Slice)
			return Continue;

		auto leftType = getExpType(asPostfix, current);
		auto leftArrayType = cast(ir.ArrayType)leftType;
		if (leftArrayType is null)
			throw CompilerPanic(loc, "OH GOD!");

		auto fn = getCopyFunction(loc, leftArrayType);

		exp = buildCall(loc, fn, [asPostfix, binOp.right], fn.name);

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
		auto typeSize = size(loc, type.base);

		ir.Exp[] args = [
			cast(ir.Exp)
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, left, "left"), "ptr")),
			buildCastToVoidPtr(loc, buildAccess(loc, buildExpReference(loc, right, "right"), "ptr")),
			buildAccess(loc, buildExpReference(loc, left, "left"), "length"),
			buildConstantInt(loc, 0),
			buildFalse(loc)
		];
		buildExpStat(loc, fn._body, buildCall(loc, expRef, args));

		buildReturn(loc, fn._body, buildExpReference(loc, fn.type.params[0], "left"));

		return fn;
	}

	ir.Function getLlvmMemMove(Location loc)
	{
		auto name32 = "llvm_memmove_p0i8_p0i8_i32";
		auto name64 = "llvm_memmove_p0i8_p0i8_i64";
		auto name = V_P64 ? name64 : name32;

		auto fn = lookupFunction(loc, name);
		if (fn !is null)
			return fn;

		if (V_P64) {
			fn = buildFunction(loc, thisModule.children, thisModule.myScope, name64, false);
			fn.mangledName = "llvm.memmove.p0i8.p0i8.i64";
			addParam(loc, fn, buildVoidPtr(loc), "dst");
			addParam(loc, fn, buildVoidPtr(loc), "src");
			addParam(loc, fn, buildUlong(loc), "len");
			addParam(loc, fn, buildInt(loc), "align");
			addParam(loc, fn, buildBool(loc), "isvolatile");
		} else {
			fn = buildFunction(loc, thisModule.children, thisModule.myScope, name32, false);
			fn.mangledName = "llvm.memmove.p0i8.p0i8.i32";
			addParam(loc, fn, buildVoidPtr(loc), "dst");
			addParam(loc, fn, buildVoidPtr(loc), "src");
			addParam(loc, fn, buildUint(loc), "len");
			addParam(loc, fn, buildInt(loc), "align");
			addParam(loc, fn, buildBool(loc), "isvolatile");
		}

		assert(fn !is null);
		return fn;
	}

	ir.Function lookupFunction(Location loc, string name)
	{
		// Lookup the copy function for this type of array.
		auto store = thisModule.myScope.lookupOnlyThisScope(name, loc);
		if (store !is null && store.kind == ir.Store.Kind.Function) {
			assert(store.functions.length == 1);
			return store.functions[0];
		}
		return null;
	}
}
