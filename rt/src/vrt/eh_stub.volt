// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.eh_stub;


version (Emscripten):

extern(C) void exit(int);

extern(C) void vrt_eh_throw(object.Throwable t, string file, size_t line)
{
	object.vrt_printf("###EXCEPTION###\n%.*s:%i %*.s\n".ptr,
		cast(int)file.length, file.ptr,
		cast(int)line,
		cast(int)t.message.length, t.message.ptr);
	exit(-1);
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
