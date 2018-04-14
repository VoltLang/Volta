// Copyright 2013-2016, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
// Written by hand from documentation.
/*!
 * @ingroup cbind
 * @ingroup winbind
 */
module core.c.windows.wgl;

version (Windows):

import core.c.windows.windows;

extern (Windows):

alias HGLRC = HANDLE;

fn wglMakeCurrent(hdc: HDC, hglrc: HGLRC) BOOL;
fn wglDeleteContext(hglrc: HGLRC) BOOL;
fn wglCreateContext(hdc: HDC) HGLRC;
fn wglGetProcAddress(LPCSTR) PROC;
