// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.varargs;


alias va_list = void*;
fn va_start(vl: va_list);
fn va_end(vl: va_list);
