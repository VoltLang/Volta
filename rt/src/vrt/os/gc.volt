// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013, David Herberth.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.gc;

import core.object : Object;
import core.typeinfo : TypeInfo;
import core.rt.gc : Stats, AllocDg;
import core.compiler.llvm : __llvm_memset, __llvm_memcpy;


version (Emscripten) {

	private extern(C) {
		fn GC_INIT();
		fn GC_MALLOC(size_t) void*;
		fn GC_MALLOC_ATOMIC(size_t) void*;
		fn GC_REGISTER_FINALIZER_NO_ORDER(obj : void*,
		                                  func : GC_finalization_proc,
		                                  cd : void*,
		                                  ofn : GC_finalization_proc*,
		                                  ocd : void**);
		fn GC_FORCE_COLLECT();

		extern global GC_java_finalization : i32;
		alias GC_finalization_proc = void function(void* obj, void* client_data);
	}

	alias GC_init = GC_INIT;
	alias GC_malloc = GC_MALLOC;
	alias GC_malloc_atomic = GC_MALLOC_ATOMIC;
	alias GC_register_finalizer_no_order = GC_REGISTER_FINALIZER_NO_ORDER;
	alias GC_gcollect = GC_FORCE_COLLECT;

} else {

	private extern(C) {
		fn GC_init();
		fn GC_malloc(size_in_bytes : size_t) void*;
		fn GC_malloc_atomic(size_in_bytes : size_t) void*;

		// Debian stable (sqeezy and wheezy libgc versions don't export that function)
		//void GC_set_java_finalization(int on_off);
		fn GC_register_finalizer_no_order(obj : void*,
		                                  func : GC_finalization_proc,
		                                  cd : void*,
		                                  ofn : GC_finalization_proc*,
		                                  ocd : void**);

		// Also not available in older libgc versions
		//void GC_gcollect_and_unmap();
		fn GC_gcollect();

		version(Windows) {
			extern(C) fn GC_win32_free_heap();
		}

		extern global GC_java_finalization : i32;
		alias GC_finalization_proc = void function(void* obj, void* client_data);
	}

}


global stats : Stats;

extern(C) fn vrt_gc_init()
{
	GC_init();
	//GC_set_java_finalization(1);
	GC_java_finalization = 1;
}

extern(C) fn vrt_gc_get_stats(out res : Stats)
{
	res = stats;
}

extern(C) fn vrt_gc_get_alloc_dg() AllocDg
{
	structToDg : StructToDg;

	structToDg.func = cast(void*)gcMalloc;

	return *cast(AllocDg*)&structToDg;
}

extern(C) fn vrt_gc_finalize_class(objPtr : void*, client_data : void*)
{
	obj := cast(Object)objPtr;
	obj.__dtor();
}

extern(C) fn vrt_gc_shutdown()
{
	GC_gcollect();
	// somehow the GC needs two collections to cleanup everything
	GC_gcollect();
	//GC_gcollect_and_unmap();

	version(Windows) {
		GC_win32_free_heap();
	}
}

fn gcMalloc(ptr : void*, typeinfo : TypeInfo, count : size_t) void*
{
	memory : void*;
	size : size_t;
	registerFinalizer : bool = false;

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

	// Statistics
	stats.count++;

	if (typeinfo.mutableIndirection) {
		memory = GC_malloc(size);
	} else {
		memory = GC_malloc_atomic(size);
		__llvm_memset(memory, 0, size, 0, false);
	}

	if (count == cast(size_t) -1) {
		__llvm_memcpy(memory, typeinfo.classInit, typeinfo.classSize, 0, false);
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
	instance : void*;
	func : void*;
}
