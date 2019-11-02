// Copyright 2019, Collabora, Ltd.
// SPDX-License-Identifier: BSL-1.0
/*!
 * @ingroup cbind
 * @ingroup posixbind
 */
module core.c.posix.sys.stdlib;


version (CRuntime_Glibc) {
	extern(C) fn setenv(scope const(char)*, scope const(char)*, int) int;
	extern(C) fn unsetenv(scope const(char)*) int;
}
