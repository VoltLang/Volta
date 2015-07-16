// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.eh_stub;


version (Emscripten):

extern(C) void exit(int);

extern(C) void vrt_eh_throw(object.Throwable t, const(char)* file, size_t line)
{
	object.vrt_printf("EXCEPTION: %.*s\n".ptr, t.message.length, t.message.ptr);
	exit(-1);
}

extern(C) void vrt_eh_throw_slice_error(size_t length, size_t targetSize, const(char)* file, size_t line)
{
	if ((length % targetSize) != 0) {
		vrt_eh_throw(new object.Error("invalid array cast"), file, line);
	}
	return;
}

extern(C) void vrt_eh_personality_v0()
{
	return;
}

extern(C) void _Unwind_Resume()
{
	return;
}
