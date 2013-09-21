// Copyright © 2013, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.eh_stub;


version (Emscripten):

extern(C) void exit(int);
extern(C) void printf(const(char)*, ...);

extern(C) void vrt_eh_throw(object.Throwable t)
{
	printf("EXCEPTION: %.*s\n".ptr, t.message.length, t.message.ptr);
	exit(-1);
}

extern(C) void vrt_eh_personality_v0()
{
	return;
}
