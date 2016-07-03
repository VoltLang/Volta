// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.eh_stub;

import core.exception : Throwable, Error;
import core.rt.misc : vrt_panic;


version (Emscripten || MSVC || Metal):

extern(C) void vrt_eh_throw(Throwable t, string file, size_t line)
{
	const(char)[][2] msgs;
	msgs[0] = "###EXCEPTION###\n";
	msgs[1] = cast(char[])t.msg;
	vrt_panic(cast(char[][])msgs, file, line);
}

extern(C) void vrt_eh_throw_slice_error(size_t length, size_t targetSize, string file, size_t line)
{
	if ((length % targetSize) != 0) {
		vrt_eh_throw(new Error("invalid array cast"), file, line);
	}
}

extern(C) void vrt_eh_personality_v0()
{
}

extern(C) void _Unwind_Resume()
{
}
