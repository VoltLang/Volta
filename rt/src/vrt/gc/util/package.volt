// Copyright 2012-2017, Jakob Bornecrantz.
// Copyright 2013-2017, David Herberth.
// Copyright 2016-2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module vrt.gc.util;

import core.rt.format : Sink, vrt_format_u64;
import core.rt.misc : vrt_panic;

import vrt.gc.design;


/*!
 * assert(foo) -> if (!foo) { throw new ... } -> code explosion
 * Avoid real asserts, and use this function instead, in GC code.
 */
fn gcAssert(b: bool, loc: const(char)[] = __LOCATION__)
{
	if (!b) {
		tmp : const(char)[][1];
		tmp[0] = "GC panic. This is a bug in the runtime.\n";
		vrt_panic(tmp, loc);
	}
}

fn isPowerOfTwo(n: size_t) bool
{
	return (n != 0) && ((n & (n - 1)) == 0);
}

fn nextHighestPowerOfTwo(n: size_t) size_t
{
	if (isPowerOfTwo(n)) {
		return n;
	}
	n |= n >> 1;
	n |= n >> 2;
	n |= n >> 4;
	n |= n >> 8;
	n |= n >> 16;
	return ++n;
}

private global __pageSize: size_t = 0;

version (Linux || OSX) {
	extern (C) fn sysconf(i32) ptrdiff_t;
	version (Linux) {
		enum _SC_PAGESIZE = 30;
	} else version (OSX) {
		enum _SC_PAGESIZE = 29;
	}

	fn getPageSize() size_t
	{
		return cast(size_t)sysconf(_SC_PAGESIZE);
	}
} else version (Windows) {
	import core.c.windows;

	fn getPageSize() size_t
	{
		si: SYSTEM_INFO;
		GetSystemInfo(&si);
		return cast(size_t)si.dwPageSize;
	}
} else {
	fn getPageSize() size_t
	{
		return 4096;
	}
}

fn roundUpToPageSize(n: size_t) size_t
{
	if (__pageSize == 0) {
		__pageSize = getPageSize();
	}
	newn := (n + (__pageSize - 1)) & (~(__pageSize - 1));
	return newn;
}

/* Takes a void[] range and makes it into a const(void*)[] one,
 * reducing it to alignment boundaries.
 */
fn makeRange(range: const(void[])) const(void*)[]
{
	iptr := cast(size_t)range.ptr;
	aiptr := (((iptr - 1) / typeid(size_t).size) + 1) * typeid(size_t).size;

	if (range.length < 8) {
		return null;
	}

	// Align the pointer, remove the difference from the length.
	aptr := cast(const(void*)*)aiptr;
	length := (range.length - aiptr + iptr) / typeid(size_t).size;
	return aptr[0 .. length];
}

/* Takes a void[] range and makes it into a const(void*)[] one,
 * does only align the end of the array.
 */
fn makeRangeNoAlign(range: const(void[])) const(void*)[]
{
	return (cast(void**)range.ptr)[0 .. range.length / typeid(size_t).size];
}
