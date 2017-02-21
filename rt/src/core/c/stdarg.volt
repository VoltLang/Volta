// Copyright © 2013-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
module core.c.stdarg;

version (!Metal):


import core.varargs;


extern(C):
@system: // Types only.
nothrow:

alias va_list = void*;
alias va_start = core.varargs.va_start;
alias va_end = core.varargs.va_end;
