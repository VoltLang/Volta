// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc_stub;

version (MSVC || Metal):

import vrt.os.gc;
import vrt.ext.stdc : calloc;


extern(C):

fn GC_malloc(size_in_bytes : size_t) void*
{
	return calloc(1, size_in_bytes);
}

fn GC_malloc_atomic(size_in_bytes : size_t) void*
{
	return calloc(1, size_in_bytes);
}

global GC_java_finalization : i32;

fn GC_init() void {}
fn GC_gcollect() void {}
fn GC_win32_free_heap() void {}
fn GC_register_finalizer_no_order(obj : void*,
                                  func : GC_finalization_proc,
                                  cd : void*,
                                  ofn : GC_finalization_proc*,
                                  ocd : void**) void {}
