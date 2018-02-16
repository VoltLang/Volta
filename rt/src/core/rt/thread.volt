// Copyright © 2016-2017, Bernard Helyer.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Code to support spawning new threads.
 *
 * The runtime has to be aware of new threads in order
 * to make GC work, so all new threads should be
 * spawned through this interface.
 */
module core.rt.thread;
version (!Metal):

struct vrt_thread {
}

/*!
 * Construct a new thread.
 *
 * Invokes `func` in a new thread.
 *
 * Sets/clears the error on the `vrt_thread` struct.
 *
 * @Returns A pointer to a new `vrt_thread` struct.
 */
extern (C) fn vrt_thread_start_fn(func: fn()) vrt_thread*;

/*!
 * Construct a new thread.
 *
 * Invokes `dlgt` in a new thread.
 *
 * Sets/clears the error on the `vrt_thread` struct.
 *
 * @Returns A pointer to a new `vrt_thread` struct.
 */
extern (C) fn vrt_thread_start_dg(dlgt: dg()) vrt_thread*;

/*!
 * Did the last operation signal an error?
 */
extern (C) fn vrt_thread_error(t: vrt_thread*) bool;

/*!
 * Get an error message for the last function that set
 * the error on `t`.
 */
extern (C) fn vrt_thread_error_message(t: vrt_thread*) string;

/*!
 * Wait for this thread to complete.
 *
 * Sets/clears the error on `t`.
 */
extern (C) fn vrt_thread_join(t: vrt_thread*);

/*!
 * Cause the calling thread to sleep for `ms` milliseconds.
 */
extern (C) fn vrt_sleep(ms: u32);
