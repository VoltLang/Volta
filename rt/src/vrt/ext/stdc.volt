// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * Standard C lib functions used by the runtime.
 */
module vrt.ext.stdc;


extern(C) void* memcpy(void* destination, const(void)* source, size_t num);
extern(C) void* memmove(void* destination, const(void)* source, size_t num);
extern(C) int memcmp(const(void)* ptr1, const(void)* ptr2, size_t num);
extern(C) void memset(void* ptr, int pattern, size_t num);

extern(C) size_t strlen(const(char)* str);

extern(C) void* calloc(size_t num, size_t size);

extern(C) void exit(int);
