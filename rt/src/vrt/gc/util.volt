// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013, David Herberth.  All rights reserved.
// Copyright © 2016, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.util;

import vrt.ext.stdc : printf, exit;

/**
 * assert(foo) -> if (!foo) { throw new ... } -> code explosion
 * Avoid real asserts, and use this function instead, in GC code.
 */
fn gcAssert(b: bool, loc: const(char)* = __LOCATION__)
{
	if (!b) {
		printf("GC panic at '%s'. This is a bug in the runtime.\n", loc);
		exit(1);
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
	import vrt.ext.windows;

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

	// Align the pointer, remove the difference from the length.
	aptr := cast(const(void*)*)aiptr;
	if (range.length < 8) {
		return aptr[0 .. 0];
	}

	length := (range.length - aiptr + iptr) / typeid(size_t).size;
	return aptr[0 .. length];
}
