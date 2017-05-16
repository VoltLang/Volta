// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.mman.windows;

version (Windows):

import core.c.windows;


fn pages_map(addr: void*, size: size_t) void*
{
	return VirtualAlloc(addr, size, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
}

fn pages_reserve(addr: void*, size: size_t) void*
{
	return VirtualAlloc(addr, size, MEM_RESERVE, PAGE_EXECUTE_READWRITE);
}

fn pages_commit(addr: void*, size: size_t) bool
{
	return VirtualAlloc(addr, size, MEM_COMMIT, PAGE_EXECUTE_READWRITE) !is null;
}

fn pages_uncommit(addr: void*, size: size_t) bool
{
	return VirtualFree(addr, size, MEM_DECOMMIT) != 0;
}

fn pages_unmap(addr: void*, size: size_t)
{
	// "If the dwFreeType parameter is MEM_RELEASE, (size) must be 0." -msdn
	VirtualFree(addr, 0, MEM_RELEASE);
}
