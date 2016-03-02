// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.panic;

import vrt.ext.stdc : exit, printf;


extern(C) void vrt_panic(const(char)[][] msgs, const(char)[] file, int line)
{
	printf("%.*s:%i: ###PANIC###\n",
		cast(int)file.length, file.ptr,
		cast(int)line);

	foreach (msg; msgs) {
		printf("%.*s\n", cast(int)msg.length, msg.ptr);
	}

	exit(-1);
}
