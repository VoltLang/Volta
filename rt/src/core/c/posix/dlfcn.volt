// Copyright 2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
// Written by hand from documentation.
//! `dlopen` and friends.
module core.c.posix.dlfcn;

version (Posix):

extern (C):

fn dlopen(file: const(char)*, mode: i32) void*;
fn dlclose(handle: void*) i32;
fn dlsym(handle: void*, name: const(char)*) void*;
fn dlerror() char*;

enum RTLD_NOW    = 0x00002;
enum RTLD_GLOBAL = 0x00100;
