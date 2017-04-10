// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
/**
 * Standard C lib functions used by the runtime.
 */
module vrt.ext.stdc;

version (CRuntime_All):

public import core.c.stdint : uintptr_t;
public import core.c.stdlib : exit, getenv, calloc, realloc, free;
public import core.c.stdio : fprintf, fflush, stderr, printf, snprintf;
