// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc;

import object;


extern(C) AllocDg vrt_gc_get_alloc_dg()
{
	StructToDg structToDg;

	structToDg.func = cast(void*)mallocFunc;

	return *cast(AllocDg*)&structToDg;
}

void* mallocFunc(uint size, void *ptr)
{
	return malloc(size);
}

extern(C) void* malloc(uint size);

/**
 * Struct used to go from function instance pair to a delegate.
 */
struct StructToDg
{
	void *instance;
	void *func;
}
