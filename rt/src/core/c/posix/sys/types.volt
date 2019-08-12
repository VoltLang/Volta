// Copyright 2017, Bernard Helyer
// Copyright 2005-2009, Sean Kelly.
// SPDX-License-Identifier: BSL-1.0
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup posixbind
 */
module core.c.posix.sys.types;

version (Posix):

private import core.c.posix.config;
private import core.c.stdint;
public import core.c.stddef; // for size_t
public import core.c.time;   // for clock_t, time_t


extern(C):
@trusted:
nothrow:

//
// Required
//
/*
blkcnt_t
blksize_t
dev_t
gid_t
ino_t
mode_t
nlink_t
off_t
pid_t
size_t
ssize_t
time_t
uid_t
*/

version (Linux) {

	// static if (__USE_FILE_OFFSET64)
	version (none) {

		alias blkcnt_t = i64;
		alias ino_t = u64;
		alias off_t = i64;

	} else {

		alias blkcnt_t = c_long;
		alias ino_t = c_ulong;
		alias off_t = c_long;

	}

	alias blksize_t = c_long;
	alias dev_t = u64;
	alias gid_t = u32;
	alias mode_t = u32;
	version (AArch64) {
		alias nlink_t = u32;
	} else {
		alias nlink_t = c_ulong;
	}
	alias pid_t = i32;
	//size_t (defined in core.stdc.stddef)
	alias ssize_t = c_long;
	//time_t (defined in core.stdc.time)
	alias uid_t = u32;

} else version (OSX) {

	alias blkcnt_t = i64;
	alias blksize_t = i32;
	alias dev_t = i32;
	alias gid_t = u32;
	alias ino_t = u32;
	alias mode_t = u16;
	alias nlink_t = u16;
	alias off_t = i64;
	alias pid_t = i32;
	//size_t (defined in core.stdc.stddef)
	alias c_long = ptrdiff_t;
	//time_t (defined in core.stdc.time)
	alias ssize_t = c_long;
	alias uid_t = u32;
}

//
// XOpen (XSI)
//
/*
clock_t
fsblkcnt_t
fsfilcnt_t
id_t
key_t
suseconds_t
useconds_t
*/

version (Linux)
{
	// static if (__USE_FILE_OFFSET64)
	version (none) {

		alias fsblkcnt_t = u64;
		alias fsfilcnt_t = u64;

	} else {

		alias fsblkcnt_t = c_ulong;
		alias fsfilcnt_t = c_ulong;

	}

	// clock_t (defined in core.stdc.time)
	alias id_t        = u32;
	alias key_t       = i32;
	alias suseconds_t = c_long;
	alias useconds_t  = u32;

} else version (OSX) {

	//clock_t
	alias fsblkcnt_t  = u32;
	alias fsfilcnt_t  = u32;
	alias id_t        = u32;
	// key_t
	alias suseconds_t = i32;
	alias useconds_t  = u32;
}

//
// Thread (THR)
//
/*
pthread_attr_t
pthread_cond_t
pthread_condattr_t
pthread_key_t
pthread_mutex_t
pthread_mutexattr_t
pthread_once_t
pthread_rwlock_t
pthread_rwlockattr_t
pthread_t
*/

/+version (Linux) {

	version (V_P64) {

		enum __SIZEOF_PTHREAD_ATTR_T = 56;
		enum __SIZEOF_PTHREAD_MUTEX_T = 40;
		enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
		enum __SIZEOF_PTHREAD_COND_T = 48;
		enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
		enum __SIZEOF_PTHREAD_RWLOCK_T = 56;
		enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
		enum __SIZEOF_PTHREAD_BARRIER_T = 32;
		enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;

	} else {

		enum __SIZEOF_PTHREAD_ATTR_T = 36;
		enum __SIZEOF_PTHREAD_MUTEX_T = 24;
		enum __SIZEOF_PTHREAD_MUTEXATTR_T = 4;
		enum __SIZEOF_PTHREAD_COND_T = 48;
		enum __SIZEOF_PTHREAD_CONDATTR_T = 4;
		enum __SIZEOF_PTHREAD_RWLOCK_T = 32;
		enum __SIZEOF_PTHREAD_RWLOCKATTR_T = 8;
		enum __SIZEOF_PTHREAD_BARRIER_T = 20;
		enum __SIZEOF_PTHREAD_BARRIERATTR_T = 4;

	}

	union pthread_attr_t
	{
		byte __size[__SIZEOF_PTHREAD_ATTR_T];
		c_long __align;
	}

	private alias __atomic_lock_t = int;

	private struct _pthread_fastlock
	{
		c_long          __status;
		__atomic_lock_t __spinlock;
	}

	private alias _pthread_descr = void*;

	union pthread_cond_t
	{
		byte __size[__SIZEOF_PTHREAD_COND_T];
		long  __align;
	}

	union pthread_condattr_t
	{
		byte __size[__SIZEOF_PTHREAD_CONDATTR_T];
		int __align;
	}

	alias pthread_key_t = uint;

	union pthread_mutex_t
	{
		byte __size[__SIZEOF_PTHREAD_MUTEX_T];
		c_long __align;
	}

	union pthread_mutexattr_t
	{
		byte __size[__SIZEOF_PTHREAD_MUTEXATTR_T];
		int __align;
	}

	alias pthread_once_t = int;

	struct pthread_rwlock_t
	{
		byte __size[__SIZEOF_PTHREAD_RWLOCK_T];
		c_long __align;
	}

	struct pthread_rwlockattr_t
	{
		byte __size[__SIZEOF_PTHREAD_RWLOCKATTR_T];
		c_long __align;
	}

	alias pthread_t = c_ulong;

} else version (OSX) {

	version (V_P64) {

		enum __PTHREAD_SIZE__               = 1168;
		enum __PTHREAD_ATTR_SIZE__          = 56;
		enum __PTHREAD_MUTEXATTR_SIZE__     = 8;
		enum __PTHREAD_MUTEX_SIZE__         = 56;
		enum __PTHREAD_CONDATTR_SIZE__      = 8;
		enum __PTHREAD_COND_SIZE__          = 40;
		enum __PTHREAD_ONCE_SIZE__          = 8;
		enum __PTHREAD_RWLOCK_SIZE__        = 192;
		enum __PTHREAD_RWLOCKATTR_SIZE__    = 16;

	} else {

		enum __PTHREAD_SIZE__               = 596;
		enum __PTHREAD_ATTR_SIZE__          = 36;
		enum __PTHREAD_MUTEXATTR_SIZE__     = 8;
		enum __PTHREAD_MUTEX_SIZE__         = 40;
		enum __PTHREAD_CONDATTR_SIZE__      = 4;
		enum __PTHREAD_COND_SIZE__          = 24;
		enum __PTHREAD_ONCE_SIZE__          = 4;
		enum __PTHREAD_RWLOCK_SIZE__        = 124;
		enum __PTHREAD_RWLOCKATTR_SIZE__    = 12;

	}

	struct pthread_handler_rec
	{
		void function(void*)  __routine;
		void*                 __arg;
		pthread_handler_rec*  __next;
	}

	struct pthread_attr_t
	{
		c_long                              __sig;
		byte[__PTHREAD_ATTR_SIZE__]         __opaque;
	}

	struct pthread_cond_t
	{
		c_long                              __sig;
		byte[__PTHREAD_COND_SIZE__]         __opaque;
	}

	struct pthread_condattr_t
	{
		c_long                              __sig;
		byte[__PTHREAD_CONDATTR_SIZE__]     __opaque;
	}

	alias pthread_key_t = c_ulong;

	struct pthread_mutex_t
	{
		c_long                              __sig;
		byte[__PTHREAD_MUTEX_SIZE__]        __opaque;
	}

	struct pthread_mutexattr_t
	{
		c_long                              __sig;
		byte[__PTHREAD_MUTEXATTR_SIZE__]    __opaque;
	}

	struct pthread_once_t
	{
		c_long                              __sig;
		byte[__PTHREAD_ONCE_SIZE__]         __opaque;
	}

	struct pthread_rwlock_t
	{
		c_long                              __sig;
		byte[__PTHREAD_RWLOCK_SIZE__]       __opaque;
	}

	struct pthread_rwlockattr_t
	{
		c_long                              __sig;
		byte[__PTHREAD_RWLOCKATTR_SIZE__]   __opaque;
	}

	private struct _opaque_pthread_t
	{
		c_long                  __sig;
		pthread_handler_rec*    __cleanup_stack;
		byte[__PTHREAD_SIZE__]  __opaque;
	}

	alias pthread_t = _opaque_pthread_t*;

} else version (FreeBSD) {

	alias lwpid_t = int;

	alias pthread_attr_t       = void*;
	alias pthread_cond_t       = void*;
	alias pthread_condattr_t   = void*;
	alias pthread_key_t        = void*;
	alias pthread_mutex_t      = void*;
	alias pthread_mutexattr_t  = void*;
	alias pthread_once_t       = void*;
	alias pthread_rwlock_t     = void*;
	alias pthread_rwlockattr_t = void*;
	alias pthread_t            = void*;

}+/

//
// Barrier (BAR)
//
/*
pthread_barrier_t
pthread_barrierattr_t
*/

/+version (Linux) {

	struct pthread_barrier_t
	{
		byte __size[__SIZEOF_PTHREAD_BARRIER_T];
		c_long __align;
	}

	struct pthread_barrierattr_t
	{
		byte __size[__SIZEOF_PTHREAD_BARRIERATTR_T];
		int __align;
	}

} else version(FreeBSD) {

	alias pthread_barrier_t = void*;
	alias pthread_barrierattr_t = void*;

}+/

//
// Spin (SPN)
//
/*
pthread_spinlock_t
*/

version (Linux) {

    alias pthread_spinlock_t = i32; // volatile

} else version (OSX) {

    //struct pthread_spinlock_t;

}

//
// Timer (TMR)
//
/*
clockid_t
timer_t
*/

//
// Trace (TRC)
//
/*
trace_attr_t
trace_event_id_t
trace_event_set_t
trace_id_t
*/
