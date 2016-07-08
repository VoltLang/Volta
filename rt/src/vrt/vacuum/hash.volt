// Copyright © 2014, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.vacuum.hash;


/**
 * Generate a hash.
 * djb2 algorithm stolen from http://www.cse.yorku.ca/~oz/hash.html
 *
 * This needs to correspond with the implementation
 * in volt.util.string in the compiler.
 */
extern(C) fn vrt_hash(ptr : void*, length : size_t) u32
{
	h : u32 = 5381;

	uptr : u8* = cast(u8*) ptr;

	foreach (i; 0 .. length) {
		h = ((h << 5) + h) + uptr[i];
	}

	return h;
}
