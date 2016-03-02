// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc_stub;

version (MSVC):

import vrt.os.gc;

extern(C):

void* calloc(size_t num, size_t size);

void* GC_malloc(size_t size_in_bytes)
{
	return calloc(1, size_in_bytes);
}

void* GC_malloc_atomic(size_t size_in_bytes)
{
	return calloc(1, size_in_bytes);
}

global int GC_java_finalization;

void GC_init() {}
void GC_gcollect() {}
void GC_win32_free_heap() {}
void GC_register_finalizer_no_order(void* obj,
                                    GC_finalization_proc fn,
                                    void* cd,
                                    GC_finalization_proc* ofn,
                                    void** ocd) {}
