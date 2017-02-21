// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.panic;

import vrt.ext.stdc: exit, printf;


extern(C) fn vrt_panic(msgs: const(char)[][], location: const(char)[])
{
	printf("%.*s: ###PANIC###\n",
		cast(int)location.length, location.ptr);

	foreach (msg; msgs) {
		printf("%.*s\n", cast(int)msg.length, msg.ptr);
	}

	exit(-1);
}
