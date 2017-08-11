// Copyright © 2017, Bernard Helyer.  All rights reserved.
//! Assorted OSX function bindings.
module core.c.osx;

version (OSX):

extern(C):

fn _NSGetExecutablePath(char*, u32*) i32;
