// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.value;

import lib.llvm.core;

import volt.errors;
import volt.ir.util;
import volt.llvm.interfaces;


/**
 * Represents a single LLVMValueRef plus the associated high level type.
 *
 * A Value can be in reference form where it is actually a pointer
 * to the give value, since all variables are stored as alloca'd
 * memory in a function we will not insert loads until needed.
 * This is needed for '&' to work and struct lookups.
 */
class Value
{
public:
	Type type;
	LLVMValueRef value;

	bool isPointer; ///< Is this a reference to the real value?

public:
	this()
	{
	}

	this(Value val)
	{
		this.isPointer = val.isPointer;
		this.type = val.type;
		this.value = val.value;
	}
}


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
		if (tr !is null)
			at = cast(ir.ArrayType)tr.type;
	}

	if (at is null)
		throw panic(al.location, "array literal type must be ArrayType or TypeReference");

	auto type = cast(ArrayType)state.fromIr(at);

	result.isPointer = false;
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
