// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013, David Herberth.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc;

import object;

private extern(C) {
	void GC_init();
	void* GC_malloc(size_t size_in_bytes);
	void* GC_malloc_atomic(size_t size_in_bytes);
}


extern(C) {
	void vrt_gc_init()
	{
		GC_init();
		return;
	}

	void* vrt_gc_malloc(TypeInfo typeinfo, size_t count, void *ptr) {
		size_t size;
		
		if (count == cast(uint) 0) {
			size = typeinfo.size;
		} else {
			size = count * typeinfo.size;
		}

		if(typeinfo.mutableIndirection) {
			return GC_malloc_atomic(size);
		}
		return GC_malloc(size);
	}
}



extern(C) AllocDg vrt_gc_get_alloc_dg()
{
	StructToDg structToDg;

	structToDg.func = cast(void*)vrt_gc_malloc;

	return *cast(AllocDg*)&structToDg;
}

/**
 * Struct used to go from function instance pair to a delegate.
 */
struct StructToDg
{
	void *instance;
	void *func;
}
