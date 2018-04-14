// Copyright 2016, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * @ingroup cbind
 * @ingroup posixbind
 */
module core.c.posix.spawn;

version (Posix):

import core.c.posix.sys.types;


enum u16 POSIX_SPAWN_RESETIDS           = 0x0001;
enum u16 POSIX_SPAWN_SETPGROUP          = 0x0002;
enum u16 POSIX_SPAWN_SETSIGDEF          = 0x0004;
enum u16 POSIX_SPAWN_SETSIGMASK         = 0x0008;


version (Linux) {

	enum u16 POSIX_SPAWN_SETSCHEDPARAM      = 0x0010;
	enum u16 POSIX_SPAWN_SETSCHEDULER       = 0x0020;
	enum u16 POSIX_SPAWN_USEVFORK           = 0x0040;

	version (X86) {

		struct posix_spawn_file_actions { __data: void[76]; }
		struct posix_spawnattr { __data: void[336]; }

	} else version (X86_64) {

		struct posix_spawn_file_actions { __data: void[80]; }
		struct posix_spawnattr { __data: void[336]; }

	} else {

		static assert(false, "unsupported arch");
	}

	alias posix_spawn_file_actions_t = posix_spawn_file_actions;
	alias posix_spawnattr_t = posix_spawnattr;

} else version (OSX) {

	enum u16 POSIX_SPAWN_SETEXEC            = 0x0040;
	enum u16 POSIX_SPAWN_START_SUSPENDED    = 0x0080;
	enum u16 POSIX_SPAWN_CLOEXEC_DEFAULT    = 0x4000;

	struct posix_spawn_file_actions {}
	struct posix_spawnattr {}

	alias posix_spawn_file_actions_t = posix_spawn_file_actions*;
	alias posix_spawnattr_t = posix_spawnattr*;

}


extern(C):

fn posix_spawn(pid_t* , const(char)* ,
                const(posix_spawn_file_actions_t)* ,
                const(posix_spawnattr_t)* ,
                const(char*)* , const(char*)* ) i32;
fn posix_spawn(pid_t* , const(char)* ,
                const(posix_spawn_file_actions_t)* ,
                const(posix_spawnattr_t)* ,
                const(char*)* , const(char*)* ) i32;


fn posix_spawnattr_init(posix_spawnattr_t*) i32;
fn posix_spawnattr_destroy(posix_spawnattr_t*) i32;
//int posix_spawnattr_getsigdefault(const(posix_spawnattr_t)*, sigset_t*);
//int posix_spawnattr_setsigdefault(posix_spawnattr_t*, const(sigset_t)*);
//int posix_spawnattr_getsigmask(const(posix_spawnattr_t)*, sigset_t*);
//int posix_spawnattr_setsigmask(posix_spawnattr_t*, const(sigset_t)*);
fn posix_spawnattr_getflags(const(posix_spawnattr_t)*, i16*) i32;
fn posix_spawnattr_setflags(posix_spawnattr_t*, i16) i32;
fn posix_spawnattr_getpgroup (const(posix_spawnattr_t)*, pid_t*) i32;
fn posix_spawnattr_setpgroup (posix_spawnattr_t*, pid_t) i32;
fn posix_spawnattr_getschedpolicy (const(posix_spawnattr_t)*, i32*) i32;
fn posix_spawnattr_setschedpolicy (posix_spawnattr_t*, i32) i32;
//int posix_spawnattr_getschedparam (const(posix_spawnattr_t)*, sched_param*,);
//int posix_spawnattr_setschedparam (posix_spawnattr_t*, const(sched_param)*);
fn posix_spawn_file_actions_init (posix_spawn_file_actions_t*) i32;
fn posix_spawn_file_actions_destroy (posix_spawn_file_actions_t*) i32;
fn posix_spawn_file_actions_addopen (posix_spawn_file_actions_t*, i32, const(char)*, i32, mode_t) i32;
fn posix_spawn_file_actions_addclose (posix_spawn_file_actions_t*, i32) i32;
fn posix_spawn_file_actions_adddup2 (posix_spawn_file_actions_t*, i32, i32) i32;
