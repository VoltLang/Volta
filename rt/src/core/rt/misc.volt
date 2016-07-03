// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.misc;

import core.typeinfo;
import core.exception;


extern(C):

/*
 * Exception handling
 */
void vrt_eh_throw(Throwable, string filename, size_t line);
void vrt_eh_throw_slice_error(string filename, size_t line);
void vrt_eh_personality_v0();

/*
 * For those very bad times.
 */
void vrt_panic(scope const(char)[][] msg, scope const(char)[] file = __FILE__, const size_t line = __LINE__);

/*
 * Language util functions
 */
void* vrt_handle_cast(void* obj, TypeInfo tinfo);
uint vrt_hash(void*, size_t);
@mangledName("memcmp") int vrt_memcmp(void*, void*, size_t);

/*
 * Starting up.
 */
int vrt_run_global_ctors();
int vrt_run_main(int argc, char** argv, int function(string[]) args);
int vrt_run_global_dtors();

/*
 * Unicode functions.
 */
dchar vrt_decode_u8_d(string str, ref size_t index);
dchar vrt_reverse_decode_u8_d(string str, ref size_t index);
