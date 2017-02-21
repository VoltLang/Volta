// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.mman.mmap;

version (Linux || OSX):


fn pages_map(addr: void*, size: size_t) void*
{
	prot := Prot.Read | Prot.Write;
	flags := Map.Private | Map.Anon;
	ret := mmap(addr, size, prot, flags, -1, 0);
	assert(ret !is null);

	MAP_FAILED := cast(void*) -1L;
	if (ret is MAP_FAILED) {
		ret = null;
	} else if (addr !is null && ret !is addr) {
		// We mapped, but not where expected.
		pages_unmap(ret, size);
		ret = null;
	}

	// XXX: out contract
	assert(ret is null ||
		(addr is null && ret !is addr) ||
		(addr !is null && ret is addr));
	return ret;
}

fn pages_unmap(addr: void*, size: size_t)
{
	ret := munmap(addr, size);
	assert(ret != -1);
}


private:

// XXX: this is a bad port of mman header.
// We should be able to use actual prot of C header soon.
alias off_t = long; // Good for now.

enum Prot {
	None	= 0x0,
	Read	= 0x1,
	Write	= 0x2,
	Exec	= 0x4,
}

version(OSX) {
	enum Map {
		Shared	= 0x01,
		Private	= 0x02,
		Fixed	= 0x10,
		Anon	= 0x1000,
	}
} else version(Linux) {
	enum Map {
		Shared	= 0x01,
		Private	= 0x02,
		Fixed	= 0x10,
		Anon	= 0x20,
	}
}

extern(C) fn mmap(void*, size_t, int, int, int, off_t) void*;
extern(C) fn munmap(void*, size_t) int;
