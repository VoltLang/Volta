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

extern @mangledName("__V_global_ctors") global globalConstructors: fn()[];
extern @mangledName("__V_global_dtors") global globalDestructors: fn()[];
extern @mangledName("__V_local_ctors") global localConstructors: fn()[];
extern @mangledName("__V_local_dtors") global localDestructors: fn()[];

struct ModuleInfo
{
	next: ModuleInfo*;
	ctors: fn ()[];
	dtors: fn ()[];
}

@mangledName("_V__ModuleInfo_root") global moduleInfoRoot: ModuleInfo*;
