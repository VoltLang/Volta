// Copyright © 2016-2017, Bernard Helyer.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
/*!
 * @ingroup cbind
 * @ingroup stdcbind
 */
module core.c.string;

version (CRuntime_All):


extern (C):

fn memcpy(dest: void*, src: const(void)*, n: size_t) void*;
fn memmove(dest: void*, src: const(void)*, n: size_t) void*;
fn strcpy(dest: char*, src: const(char)*) char*;
fn strncpy(dest: char*, src: const(char)*, n: size_t) char*;

fn strcat(dest: char*, src: const(char)*) char*;
fn strncat(dest: char*, src: const(char)*, n: size_t) char*;

fn memcmp(ptr1: const(void)*, ptr2: const(void)*, n: size_t) i32;
fn strcmp(str1: const(char)*, str2: const(char)*) i32;
fn strcoll(str1: const(char)*, str2: const(char)*) i32;
fn strncmp(str1: const(char)*, str2: const(char)*, n: size_t) i32;

fn memchr(ptr: const(void)*, val: i32, n: size_t) void*;
fn strchr(str: const(char)*, c: i32) char*;
fn strcspn(str1: const(char)*, str2: const(char)*) size_t;
fn strpbrk(str1: const(char)*, str2: const(char)*) char*;
fn strrchr(str1: const(char)*, c: i32) char*;
fn strspn(str1: const(char)*, str2: const(char)*) size_t;
fn strstr(str1: const(char)*, str2: const(char)*) char*;
fn strtok(str: char*, delim: const(char)*) char*;

fn memset(ptr: void*, v: i32, n: size_t) void*;
fn strerror(errnum: i32) char*;
fn strlen(str: const(char)*) size_t;
