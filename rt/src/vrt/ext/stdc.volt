// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
/**
 * Standard C lib functions used by the runtime.
 */
module vrt.ext.stdc;


extern(C) fn printf(const(char)*, ...) int;

extern(C) fn calloc(num: size_t, size: size_t) void*;
extern(C) fn realloc(void*, size_t) void*;
extern(C) fn free(void*);

extern(C) fn exit(i32);
extern(C) fn snprintf(char*, size_t, scope const(char)*, ...) int;

extern(C) fn getenv(const(char)*) const(char)*;

// True for now.
alias uintptr_t = size_t;
