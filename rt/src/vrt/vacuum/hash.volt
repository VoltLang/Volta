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
extern(C) uint vrt_hash(void* ptr, size_t length)
{
	uint h = 5381;

	ubyte* uptr = cast(ubyte*) ptr;

	for (size_t i = 0; i < length; i++) {
		h = ((h << 5) + h) + uptr[i];
	}

	return h;
}
