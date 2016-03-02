// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.panic;

import vrt.ext.stdc : exit;


extern(C) void vrt_panic(const(char)[][] msgs, const(char)[] file, int line)
{
	object.vrt_printf("%.*s:%i: ###PANIC###\n",
		cast(int)file.length, file.ptr,
		cast(int)line);

	foreach (msg; msgs) {
		object.vrt_printf("%.*s\n", cast(int)msg.length, msg.ptr);
	}

	exit(-1);
}
