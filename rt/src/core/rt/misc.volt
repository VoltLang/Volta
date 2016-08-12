// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.misc;

import core.typeinfo;
import core.exception;


extern(C):

/*
 * Exception handling
 */
fn vrt_eh_throw(t: Throwable, location: string);
fn vrt_eh_throw_slice_error(location: string);
fn vrt_eh_personality_v0();

/*
 * For those very bad times.
 */
fn vrt_panic(msg: scope const(char)[][], location: scope const(char)[] = __LOCATION__);

/*
 * Language util functions
 */
fn vrt_handle_cast(obj: void*, ti: TypeInfo) void*;
fn vrt_hash(data: void*, size: size_t) u32;
@mangledName("memcmp") fn vrt_memcmp(d1: void*, d2: void*, size: size_t) i32;

/*
 * Starting up.
 */
fn vrt_run_global_ctors() i32;
fn vrt_run_main(argc: i32, argv: char**, args: int function(string[])) i32;
fn vrt_run_global_dtors() i32;

/*
 * Unicode functions.
 */
fn vrt_decode_u8_d(str: string, ref index: size_t) dchar;
fn vrt_reverse_decode_u8_d(str: string, ref index: size_t) dchar;
