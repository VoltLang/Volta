// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.llvm.value;

import lib.llvm.core;
import volt.llvm.type;


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
