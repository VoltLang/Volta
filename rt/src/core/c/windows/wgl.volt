// Copyright © 2013-2016, Bernard Helyer.
// See copyright notice in src/watt/licence.volt (BOOST ver 1.0).
module core.c.windows.wgl;

version (Windows):

import core.c.windows.windows;

extern (Windows):

alias HGLRC = HANDLE;

fn wglMakeCurrent(hdc: HDC, hglrc: HGLRC) BOOL;
fn wglDeleteContext(hglrc: HGLRC) BOOL;
fn wglCreateContext(hdc: HDC) HGLRC;
fn wglGetProcAddress(LPCSTR) PROC;
