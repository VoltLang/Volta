// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.eh_stub;

import core.exception : Throwable, Error;
import core.rt.misc : vrt_panic;


version (Emscripten || MSVC || Metal):

extern(C) fn vrt_eh_throw(t : Throwable, file : string, line : size_t)
{
	msgs : const(char)[][2];
	msgs[0] = "###EXCEPTION###\n";
	msgs[1] = cast(char[])t.msg;
	vrt_panic(cast(char[][])msgs, file, line);
}

extern(C) fn vrt_eh_throw_slice_error(length : size_t, targetSize : size_t, file : string, line : size_t)
{
	if ((length % targetSize) != 0) {
		vrt_eh_throw(new Error("invalid array cast"), file, line);
	}
}

extern(C) fn vrt_eh_personality_v0()
{
}

extern(C) fn _Unwind_Resume()
{
}
