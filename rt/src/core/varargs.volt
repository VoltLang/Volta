// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.varargs;


//! Represents the list of arguments given to variadic functions.
alias va_list = void*;
//! Prepare a `va_list` for use.
fn va_start(vl: va_list);
//! Stop working with a `va_list`.
fn va_end(vl: va_list);
