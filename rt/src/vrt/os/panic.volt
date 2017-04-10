// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.panic;

version (CRuntime_All):

import vrt.ext.stdc: exit, fprintf, fflush, stderr;


extern(C) fn vrt_panic(msgs: const(char)[][], location: const(char)[])
{
	fprintf(stderr, "###PANIC###");
	fflush(stderr);
	fprintf(stderr, "%.*s\n",
		cast(int)location.length, location.ptr);

	foreach (msg; msgs) {
		fprintf(stderr, "%.*s\n", cast(int)msg.length, msg.ptr);
	}

	fflush(stderr);
	exit(-1);
}
