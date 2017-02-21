// Copyright © 2016-2017, Jakob Bornecrantz.
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

	fn toString() string
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
	next: ModuleInfo*;
	ctors: fn ()[];
	dtors: fn ()[];
}

@mangledName("_V__ModuleInfo_root") global moduleInfoRoot: ModuleInfo*;
