// Copyright 2012-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module core.rt.eh;

import core.rt.misc;
import core.exception;

extern(C):

/*!
 * Set a callback that happens just before a exception is thrown.
 *
 * The callback is per thread (for those platforms that support TLS).
 *
 * Do not throw from the callback, as it will explode.
 */
fn vrt_eh_set_callback(cb: fn(t: Throwable, location: string));

/*!
 * Perform a throw of the given `Throwable` object.
 */
fn vrt_eh_throw(t: Throwable, location: string);

/*!
 * Throw a `Throwable` that has previously been thrown.
 */
fn vrt_eh_rethrow(t: Throwable);

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
version (Windows) {
@mangledName("__CxxFrameHandler3")
fn vrt_eh_personality_v0(
	exceptionRecord:   void*,
	establisherFrame:  void*,
	contextRecord:     void*,
	dispatcherContext: void*)
	i32;
} else {
	fn vrt_eh_personality_v0(...) i32;
}
