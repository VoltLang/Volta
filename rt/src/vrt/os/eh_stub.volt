// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.eh_stub;


version (Emscripten || MSVC):

extern(C) void vrt_eh_throw(object.Throwable t, string file, size_t line)
{
	object.vrt_panic("###EXCEPTION###\n" ~ t.msg, file, line);
}

extern(C) void vrt_eh_throw_slice_error(size_t length, size_t targetSize, string file, size_t line)
{
	if ((length % targetSize) != 0) {
		vrt_eh_throw(new object.Error("invalid array cast"), file, line);
	}
}

extern(C) void vrt_eh_personality_v0()
{
}

extern(C) void _Unwind_Resume()
{
}
