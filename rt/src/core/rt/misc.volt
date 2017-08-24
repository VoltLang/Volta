// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.misc;

import core.typeinfo;
import core.exception;


extern(C):

/*
 * Exception handling
 */
/*!
 * Perform a throw of the given `Throwable` object.
 */
fn vrt_eh_throw(t: Throwable, location: string);
/*!
 * Throw an error for an invalid slice.
 */
fn vrt_eh_throw_slice_error(location: string);
/*!
 * Throw an assert for an assert failure.
 */
fn vrt_eh_throw_assert_error(location: string, msg: string);
/*!
 * Throw an AA key lookup failure error.
 */
fn vrt_eh_throw_key_not_found_error(location: string);
/*!
 * The personality function makes stack unwinding work.
 */
fn vrt_eh_personality_v0(...) i32;

/*
 * Monotonic time.
 */
/*!
 * Initialise the monotonic code.
 */
fn vrt_monotonic_init();
/*!
 * Get the ticks count.
 *
 * The ticks count is an amount of time from a specific point.
 */
fn vrt_monotonic_ticks() i64;
/*!
 * Get the runtime's initial ticks value.
 */
fn vrt_monotonic_ticks_at_init() i64;
/*!
 * Get how many ticks make up a second.
 */
fn vrt_monotonic_ticks_per_second() i64;

/*
 * For those very bad times.
 */
fn vrt_panic(msg: scope const(char)[][], location: scope const(char)[] = __LOCATION__);

/*
 * Language util functions
 */
/*!
 * Perform a runtime cast.
 */
fn vrt_handle_cast(obj: void*, ti: TypeInfo) void*;
/*!
 * Get the hash for `size` bytes of `data`.
 */
fn vrt_hash(data: void*, size: size_t) u32;
/*!
 * Perform a `memcmp` between `size` bytes of `d1` and `d2`.
 */
@mangledName("memcmp") fn vrt_memcmp(d1: void*, d2: void*, size: size_t) i32;

/*
 * Starting up.
 */
alias VMain = fn(string[]) int;

/*!
 * Run global constructors for linked modules.
 */
fn vrt_run_global_ctors() i32;
/*!
 * Run the given main function with the given arguments.
 *
 * Returns the return value of the function.
 */
fn vrt_run_main(argc: i32, argv: char**, vMain: VMain) int;
/*!
 * Run global destructors for linked modules.
 */
fn vrt_run_global_dtors() i32;

/*
 * Unicode functions.
 */
/*!
 * Encode `c` as a string in `buf`.
 *
 * @Returns How many bytes of `buf` have been used, `<= 6`.
 */
fn vrt_encode_static_u8(ref buf: char[6], c: dchar) size_t;
/*!
 * Decode a single codepoint of `str`, starting from `index`.
 *
 * `index` is updated to the next codepoint's start position.
 */
fn vrt_decode_u8_d(str: string, ref index: size_t) dchar;
/*!
 * Decode a single codepoint of `str`, starting from `index`.
 *
 * `index` is updated to the previous codepoint's start position.
 */
fn vrt_reverse_decode_u8_d(str: string, ref index: size_t) dchar;
