// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.common;

import lib.llvm.core;

import volt.errors;
import volt.ir.util;
import volt.llvm.interfaces;


/*
 *
 * Common handle functions for both inline and constants.
 *
 */


void handleArrayLiteral(State state, ir.ArrayLiteral al, Value result)
{
	auto at = cast(ir.ArrayType)al.type;
	if (at is null) {
		auto tr = cast(ir.TypeReference)al.type;
		if (tr !is null) {
			at = cast(ir.ArrayType)tr.type;
		}
	}

	if (at is null) {
		handleStaticArrayLiteral(state, al, result);
		return;
	}

	auto type = cast(ArrayType)state.fromIr(at);

	result.isPointer = false;
	result.type = type;
	result.value = type.fromArrayLiteral(state, al);
}

void handleStaticArrayLiteral(State state, ir.ArrayLiteral al, Value result)
{
	auto at = cast(ir.StaticArrayType)al.type;
	if (at is null) {
		auto tr = cast(ir.TypeReference)al.type;
		if (tr !is null) {
			at = cast(ir.StaticArrayType)tr.type;
		}
	}

	if (at is null) {
		throw panic(al.location, "array literal type must be ArrayType or TypeReference");
	}

	auto type = cast(StaticArrayType)state.fromIr(at);

	result.isPointer = true;
	result.type = type;
	result.value = type.fromArrayLiteral(state, al);
}

void handleStructLiteral(State state, ir.StructLiteral sl, Value result)
{
	auto tr = cast(ir.TypeReference)sl.type;
	if (tr is null)
		throw panic(sl.location, "struct literal type must be TypeReference");

	auto st = cast(ir.Struct)tr.type;
	if (st is null)
		throw panic(sl.location, "struct literal type must be TypeReference");

	auto type = cast(StructType)state.fromIr(st);

	result.isPointer = false;
	result.type = type;
	result.value = type.fromStructLiteral(state, sl);
}

void handleUnionLiteral(State state, ir.UnionLiteral ul, Value result)
{
	auto tr = cast(ir.TypeReference)ul.type;
	if (tr is null) {
		throw panic(ul.location, "union literal type must be a TypeReference");
	}

	auto ut = cast(ir.Union)tr.type;
	if (ut is null) {
		throw panic(ul.location, "union literal type must resolve to Union");
	}

	auto type = cast(UnionType)state.fromIr(ut);
	if (type is null) {
		throw panic(ul.location, "couldn't retrieve UnionType");
	}

	result.isPointer = false;
	result.type = type;
	result.value = type.fromUnionLiteral(state, ul);
}

void handleClassLiteral(State state, ir.ClassLiteral cl, Value result)
{
	auto tr = cast(ir.TypeReference)cl.type;
	if (tr is null)
		throw panic(cl.location, "class literal type must be TypeReference");

	auto _class = cast(ir.Class)tr.type;
	if (_class is null)
		throw panic(cl.location, "class literal type must be TypeReference");

	auto pt = cast(PointerType)state.fromIr(_class);
	auto st = cast(StructType)pt.base;

	auto sl = new ir.StructLiteral();
	sl.location = cl.location;
	sl.type = copyTypeSmart(_class.location, _class.layoutStruct);
	auto eref = buildExpReference(cl.location, _class.vtableVariable, _class.vtableVariable.name);
	sl.exps ~= buildAddrOf(cl.location, eref);
	sl.exps ~= cl.exps;

	auto v = st.fromStructLiteral(state, sl);

	if (cl.useBaseStorage) {
		result.isPointer = false;
		result.type = st;
		result.value = v;
	} else {
		auto g = LLVMAddGlobal(state.mod, st.llvmType, "");
		LLVMSetGlobalConstant(g, true);
		LLVMSetInitializer(g, v);

		result.isPointer = false;
		result.type = pt;
		result.value = g;
	}
}

void handleConstant(State state, ir.Constant asConst, Value result)
{
	assert(asConst.type !is null);

	// All of the error checking should have been
	// done in other passes and unimplemented features
	// is checked for in the called functions.

	result.type = state.fromIr(asConst.type);
	result.value = result.type.fromConstant(state, asConst);
}
