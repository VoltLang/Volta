// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.panic;

import vrt.ext.stdc : exit;


extern(C) void vrt_panic(const(char)[] msg, const(char)[] file, int line)
{
	object.vrt_printf("###PANIC###\n%.*s:%i '%.*s'\n".ptr,
		cast(int)file.length, file.ptr,
		cast(int)line,
		cast(int)msg.length, msg.ptr);
	exit(-1);
}
