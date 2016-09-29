module vrt.gc.mman.windows;

version (Windows):

import vrt.ext.windows;


fn pages_map(addr: void*, size: size_t) void*
{
	return VirtualAlloc(addr, size, MEM_COMMIT | MEM_RESERVE, PAGE_EXECUTE_READWRITE);
}

fn pages_unmap(addr: void*, size: size_t)
{
	// "If the dwFreeType parameter is MEM_RELEASE, (size) must be 0." -msdn
	VirtualFree(addr, 0, MEM_RELEASE);
}

