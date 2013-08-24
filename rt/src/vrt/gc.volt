// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013, David Herberth.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc;

import object;



version (Emscripten) {

	private extern(C) {
		void GC_INIT();
		void* GC_MALLOC(size_t);
		void* GC_MALLOC_ATOMIC(size_t);
		void GC_REGISTER_FINALIZER_NO_ORDER(void* obj,
		                                    GC_finalization_proc fn,
		                                    void* cd,
		                                    GC_finalization_proc* ofn,
		                                    void** ocd);
		void GC_FORCE_COLLECT();

		extern global int GC_java_finalization;
		alias GC_finalization_proc = void function(void* obj, void* client_data);
	}

	alias GC_init = GC_INIT;
	alias GC_malloc = GC_MALLOC;
	alias GC_malloc_atomic = GC_MALLOC_ATOMIC;
	alias GC_register_finalizer_no_order = GC_REGISTER_FINALIZER_NO_ORDER;
	alias GC_gcollect = GC_FORCE_COLLECT;

} else {

	private extern(C) {
		void GC_init();
		void* GC_malloc(size_t size_in_bytes);
		void* GC_malloc_atomic(size_t size_in_bytes);

		// Debian stable (sqeezy and wheezy libgc versions don't export that function)
		//void GC_set_java_finalization(int on_off);
		void GC_register_finalizer_no_order(void* obj,
		                                    GC_finalization_proc fn,
		                                    void* cd,
		                                    GC_finalization_proc* ofn,
		                                    void** ocd);

		// Also not available in older libgc versions
		//void GC_gcollect_and_unmap();
		void GC_gcollect();

		version(Windows) {
			extern(C) void GC_win32_free_heap();
		}

		extern global int GC_java_finalization;
		alias GC_finalization_proc = void function(void* obj, void* client_data);
	}

}

extern(C) void vrt_gc_init()
{
	GC_init();
	//GC_set_java_finalization(1);
	GC_java_finalization = 1;

	return;
}

extern(C) AllocDg vrt_gc_get_alloc_dg()
{
	StructToDg structToDg;

	structToDg.func = cast(void*)gcMalloc;

	return *cast(AllocDg*)&structToDg;
}

extern(C) void vrt_gc_finalize_class(void* obj, void* client_data)
{
	(cast(Object)obj).__dtor();
	return;
}

extern(C) void vrt_gc_shutdown()
{
	GC_gcollect();
	// somehow the GC needs two collections to cleanup everything
	GC_gcollect();
	//GC_gcollect_and_unmap();

	version(Windows) {
		GC_win32_free_heap();
	}

	return;
}

void* gcMalloc(TypeInfo typeinfo, size_t count, void *ptr)
{
	void* memory;
	size_t size;
	bool registerFinalizer = false;

	if (count == cast(size_t) 0) {
		size = typeinfo.size;
	} else if (count == cast(size_t) -1) {
		// Hack for now.
		size = typeinfo.classSize;
		// We have a class and we want its dtor to be called.
		registerFinalizer = true;
	} else {
		size = typeinfo.size;
		size = count * typeinfo.size;
	}

	if (typeinfo.mutableIndirection) {
		memory = GC_malloc(size);
	} else {
		memory = GC_malloc_atomic(size);
	}

	if (count == cast(size_t) -1) {
		(cast(void**)memory)[0] = typeinfo.classVtable;
	}


	if (registerFinalizer) {
		GC_register_finalizer_no_order(memory, vrt_gc_finalize_class, null, null, null);
	}

	return memory;
}

/**
 * Struct used to go from function instance pair to a delegate.
 */
struct StructToDg
{
	void *instance;
	void *func;
}
