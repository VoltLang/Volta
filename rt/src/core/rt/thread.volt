// Copyright 2016-2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Code to support spawning new threads.
 *
 * The runtime has to be aware of new threads in order
 * to make GC work, so all new threads should be
 * spawned through this interface.
 */
module core.rt.thread;

version (!Metal):

/*!
 * An opaque data type representing a thread.
 */
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

/*!
 * An opaque data type representing a mutex.
 */
struct vrt_mutex {
}

/*!
 * Create a new mutex.
 *
 * The mutex is not owned by any thread.
 */
extern (C) fn vrt_mutex_new() vrt_mutex*;

/*!
 * Release any resources acquired by mutex creation.
 *
 * Behaviour is undefined if the mutex is locked.
 */
extern (C) fn vrt_mutex_delete(mutex: vrt_mutex*);

/*!
 * The calling thread tries to gain ownership of `mutex`.
 *
 * If ownership could not be gained immediately, this function
 * immediately returns `false`. Otherwise `true` is returned,
 * and the thread gains ownership of the mutex.
 */
extern (C) fn vrt_mutex_trylock(mutex: vrt_mutex*) bool;

/*!
 * The calling thread tries to gain ownership of `mutex`.
 *
 * This function blocks until ownership is gained, or an
 * error occurs. If this returns `true`, the calling thread
 * gains ownership of the mutex.
 */
extern (C) fn vrt_mutex_lock(mutex: vrt_mutex*) bool;

/*!
 * Release the lock the calling thread has on `mutex`.
 *
 * If the calling thread does not have the lock on
 * `mutex`, behaviour is undefined.
 */
extern (C) fn vrt_mutex_unlock(mutex: vrt_mutex*);
