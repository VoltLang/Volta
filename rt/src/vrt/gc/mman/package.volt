// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.mman;


version (Windows) {
	public import vrt.gc.mman.windows;
} else version (Linux || OSX) {
	public import vrt.gc.mman.mmap;
} else {
	fn pages_map(addr: void*, size: size_t) void* { return null; }
	fn pages_unmap(addr: void*, size: size_t) {}
}
