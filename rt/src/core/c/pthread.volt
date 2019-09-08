// Copyright 2018, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Pthread bindings.
 *
 * Just enough to start and join a thread.
 */
module core.c.pthread;
extern (C):

import core.c.config;

alias pthread_t = c_ulong;

fn pthread_create(pthread_t*, void*, fn(void*) void*, void*) i32;
fn pthread_join(pthread_t, void*) i32;


private enum MutexMaxSize = 60;

union pthread_mutex_t
{
private:
	padding: u8[MutexMaxSize];
}

fn pthread_mutex_init(pthread_mutex_t*, void*) i32;
fn pthread_mutex_destroy(pthread_mutex_t*) i32;
fn pthread_mutex_lock(pthread_mutex_t*) i32;
fn pthread_mutex_trylock(pthread_mutex_t*) i32;
fn pthread_mutex_unlock(pthread_mutex_t*) i32;

