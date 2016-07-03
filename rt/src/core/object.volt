// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.object;


/*
 *
 * Root objects for classes and attributes.
 *
 */

/**
 * Root for all classes.
 */
class Object
{
	~this() {}

	string toString()
	{
		return "core.object.Object";
	}
}

/**
 * Base class for all user defined attributes.
 */
class Attribute
{
}


/*
 *
 * Module support.
 *
 */

struct ModuleInfo
{
	ModuleInfo* next;
	void function()[] ctors;
	void function()[] dtors;
}

@mangledName("_V__ModuleInfo_root") global ModuleInfo* moduleInfoRoot;


/*
 *
 * ABI
 *
 */

struct ArrayStruct
{
	size_t length;
	void* ptr;
}
