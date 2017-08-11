// Copyright © 2005-2009, Sean Kelly.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup stdcbind
 */
module core.c.stdlib;

version (CRuntime_All):


private import core.c.config;
public import core.c.stddef; // for size_t, wchar_t


extern(C):
@system:
nothrow:

struct div_t
{
	quot: i32;
	rem: i32;
}

struct ldiv_t
{
	quot: c_long;
	rem: c_long;
}

struct lldiv_t
{
	quot: i64;
	rem: i64;
}

enum EXIT_SUCCESS = 0;
enum EXIT_FAILURE = 1;
enum MB_CUR_MAX   = 1;

version (Windows)         enum RAND_MAX = 0x7fff;
else version (Linux)      enum RAND_MAX = 0x7fffffff;
else version (OSX)        enum RAND_MAX = 0x7fffffff;
else version (FreeBSD)    enum RAND_MAX = 0x7fffffff;
else version (Solaris)    enum RAND_MAX = 0x7fff;
else static assert(false, "Unsupported platform");

fn  atof(in nptr: char*) f64;
fn  atoi(in nptr: char*) i32;
fn  atol(in nptr: char*) c_long;
fn  atoll(in nptr: char*) i64;

fn  strtod(in nptr: char*, endptr: char**) f64;
fn   strtof(in nptr: char*, endptr: char**) f32;
//real  strtold(in nptr: char*, endptr: char**);
fn  strtol(in nptr: char*, endptr: char**, base: i32) c_long;
fn    strtoll(in nptr: char*, endptr: char**, base: i32) i64;
fn strtoul(in nptr: char*, endptr: char**, base: i32) c_ulong;
fn   strtoull(in nptr: char*, endptr: char**, base: i32) u64;

// No unsafe pointer manipulation.
@trusted
{
	fn rand() i32;
	fn srand(seed: u32);
}

// We don't mark these @trusted. Given that they return a void*, one has
// to do a pointer cast to do anything sensible with the result. Thus,
// functions using these already have to be @trusted, allowing them to
// call @system stuff anyway.
fn malloc(size: size_t) void*;
fn calloc(nmemb: size_t, size: size_t) void*;
fn realloc(ptr: void*, size: size_t) void*;
fn free(ptr: void*);

fn abort();
fn exit(status: i32);
fn atexit(func: fn()) i32;
fn _Exit(status: i32);

fn getenv(in name: char*) char*;
fn system(in str: char*) i32;

fn bsearch(in key: void*, in base: void*, nmemb: size_t, size: size_t, compar: fn(in void*, in void*) i32) void*;
fn qsort(base: void*, nmemb: size_t, size: size_t, compar: fn(in void*, in void*) i32);

// These only operate on integer values.
@trusted
{
	pure fn abs(j: i32) i32;
	pure fn labs(j: c_long) c_long;
	pure fn llabs(j: i64) i64;

	fn div(numer: i32, denom: i32) div_t;
	fn ldiv(numer: c_long, denom: c_long) ldiv_t;
	fn lldiv(numer: i64, denom: i64) lldiv_t;
}

fn mblen(in s: char*, n: size_t) i32;
fn mbtowc(pwc: wchar_t*, in s: char*, n: size_t) i32;
fn wctomb(s: char*, wc: wchar_t) i32;
fn mbstowcs(pwcs: wchar_t*, in s: char*, n: size_t) size_t;
fn wcstombs(s: char*, in pwcs: wchar_t*, n: size_t) size_t;

version (OSX) {
	import core.c.osx;

	@property fn environ() char**
	{
		return *_NSGetEnviron();
	}
} else version (Posix) {
	extern global environ: char**;
}

version (Posix) {
	fn realpath(const(char)*, char*) char*;
}
