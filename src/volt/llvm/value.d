// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.value;

import lib.llvm.core;

import volt.exceptions;
import volt.llvm.type;
import volt.llvm.state;


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


void handleStructLiteral(State state, ir.StructLiteral sl, Value result)
{
	auto tr = cast(ir.TypeReference)sl.type;
	if (tr is null)
		throw CompilerPanic(sl.location, "struct literal type must be TypeReference");

	auto st = cast(ir.Struct)tr.type;
	if (st is null)
		throw CompilerPanic(sl.location, "struct literal type must be TypeReference");

	auto type = cast(StructType)state.fromIr(st);

	result.isPointer = false;
	result.type = type;
	result.value = type.fromStructLiteral(state, sl);
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
