// Copyright 2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
// Written by hand from documentation.
//! Assorted OSX function bindings.
module core.c.osx;

version (OSX):

extern(C):

fn _NSGetExecutablePath(char*, u32*) i32;

// TODO Remove this from iOS, or apps gets rejected.
fn _NSGetEnviron() char*** ;