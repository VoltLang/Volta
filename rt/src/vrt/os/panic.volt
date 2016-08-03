// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.panic;

import vrt.ext.stdc: exit, printf;


extern(C) fn vrt_panic(msgs: const(char)[][], file: const(char)[], line: i32)
{
	printf("%.*s:%i: ###PANIC###\n",
		cast(int)file.length, file.ptr,
		cast(int)line);

	foreach (msg; msgs) {
		printf("%.*s\n", cast(int)msg.length, msg.ptr);
	}

	exit(-1);
}
