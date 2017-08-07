// Copyright © 2005-2009, Sean Kelly.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// File taken from druntime, and modified for Volt.
/*!
 * @ingroup cbind
 * @ingroup stdcbind
 */
module core.c.wchar_;

version (CRuntime_All):


private import core.c.config;
private import core.c.stdarg: va_list;
private import core.c.stdio: FILE;
public import core.c.stddef: wchar_t;
public import core.c.time: tm, time_t;
public import core.c.stdint;  // for WCHAR_MIN, WCHAR_MAX


extern (C):
@system:
nothrow:

alias mbstate_t = i32;
alias wint_t = u32;

enum wchar_t WEOF = 0xFFFF;

fn fwprintf(stream: FILE*, in format: wchar_t*, ...) i32;
fn fwscanf(stream: FILE*, in format: wchar_t*, ...) i32;
fn swprintf(s: wchar_t*, n: size_t, in format: wchar_t*, ...) i32;
fn swscanf(in s: wchar_t*, in format: wchar_t*, ...) i32;
fn vfwprintf(stream: FILE*, in format: wchar_t*, arg: va_list) i32;
fn vfwscanf(stream: FILE*, in format: wchar_t*, arg: va_list) i32;
fn vswprintf(s: wchar_t*, n: size_t, in format: wchar_t*, arg: va_list) i32;
fn vswscanf(in s: wchar_t*, in format: wchar_t*, arg: va_list) i32;
fn vwprintf(in format: wchar_t*, arg: va_list) i32;
fn vwscanf(in format: wchar_t*, arg: va_list) i32;
fn wprintf(in format: wchar_t*, ...) i32;
fn wscanf(in format: wchar_t*, ...) i32;

// No unsafe pointer manipulation.
@trusted
{
	fn fgetwc(stream: FILE*) wint_t;
	fn fputwc(c: wchar_t, stream: FILE*) wint_t;
}

fn fgetws(s: wchar_t*, n: i32, stream: FILE*) wchar_t*;
fn fputws(in s: wchar_t*, stream: FILE*) i32;

// No unsafe pointer manipulation.
extern(Volt) @trusted
{
//	wint_t getwchar()                     { return fgetwc(stdin);     }
//	wint_t putwchar(wchar_t c)            { return fputwc(c,stdout);  }
//	wint_t getwc(FILE* stream)            { return fgetwc(stream);    }
//	wint_t putwc(wchar_t c, FILE* stream) { return fputwc(c, stream); }
}

// No unsafe pointer manipulation.
@trusted
{
	fn ungetwc(c: wint_t, stream: FILE*) wint_t;
	fn fwide(stream: FILE*, mode: i32) i32;
}

fn wcstod(in wchar_t*, wchar_t**) f64;
fn wcstof(in wchar_t*, wchar_t**) f32;
//real    wcstold(in wchar_t* nptr, wchar_t** endptr);
fn wcstol(in wchar_t*, wchar_t**, i32) c_long;
fn wcstoll(in wchar_t*, wchar_t**, i32) i64;
fn wcstoul(in wchar_t*, wchar_t**, i32) c_ulong;
fn wcstoull(in wchar_t*, wchar_t**, i32) u64;

fn wcscpy(s1: wchar_t*, in s2: wchar_t*) wchar_t*;
fn wcsncpy(s1: wchar_t*, in s2: wchar_t*, n: size_t) wchar_t*;
fn wcscat(s1: wchar_t*, in s2: wchar_t*) wchar_t*;
fn wcsncat(s1: wchar_t*, in s2: wchar_t*, n: size_t) wchar_t*;
fn wcscmp(in wchar_t*, in wchar_t*) i32;
fn wcscoll(in wchar_t*, in wchar_t*) i32;
fn wcsncmp(in wchar_t*, in wchar_t*, size_t) i32;
fn wcsxfrm(wchar_t*, in wchar_t*, size_t) size_t;
fn wcschr(in wchar_t*, wchar_t) wchar_t*;
fn wcscspn(in wchar_t*, in wchar_t*) size_t;
fn wcspbrk(in wchar_t*, in wchar_t*) wchar_t*;
fn wcsrchr(in wchar_t*, wchar_t) wchar_t*;
fn wcsspn(in wchar_t*, in wchar_t*) size_t;
fn wcsstr(in wchar_t*, in wchar_t*) wchar_t*;
fn wcstok(wchar_t*, in wchar_t*, wchar_t**) wchar_t*;
fn wcslen(in wchar_t*) size_t;

fn wmemchr(in wchar_t*, wchar_t, size_t) wchar_t*;
fn wmemcmp(in wchar_t*, in wchar_t*, size_t) i32;
fn wmemcpy(wchar_t*, in wchar_t*, size_t) wchar_t*;
fn wmemmove(wchar_t*, in wchar_t*, size_t) wchar_t*;
fn wmemset(wchar_t*, wchar_t, size_t) wchar_t*;

fn wcsftime(wchar_t*, size_t, in wchar_t*, in tm*) size_t;

version (Windows) {

    fn _wasctime(tm*) wchar_t*;      // non-standard
    fn _wctime(time_t*) wchar_t*;    // non-standard
    fn _wstrdate(wchar_t*) wchar_t*; // non-standard
    fn _wstrtime(wchar_t*) wchar_t*; // non-standard

}

// No unsafe pointer manipulation.
@trusted
{
	fn btowc(i32) wint_t;
	fn wctob(wint_t) i32;
}

fn mbsinit(in mbstate_t*) i32;
fn mbrlen(in char*, size_t, mbstate_t*) size_t;
fn mbrtowc(wchar_t*, in char*, size_t, mbstate_t*) size_t;
fn wcrtomb(char*, wchar_t, mbstate_t*) size_t;
fn mbsrtowcs(wchar_t*, const(char)**, size_t, mbstate_t*) size_t;
fn wcsrtombs(char*, const(wchar_t)**, size_t, mbstate_t*) size_t;
