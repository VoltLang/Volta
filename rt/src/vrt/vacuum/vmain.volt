// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.vacuum.vmain;

import core.exception : Throwable;
import core.typeinfo : TypeInfo;
import core.rt.gc : vrt_gc_init, allocDg, vrt_gc_get_alloc_dg, vrt_gc_shutdown;
import core.rt.misc : vrt_run_global_ctors, vrt_run_global_dtors, vrt_panic;



extern(C) int vrt_run_main(int argc, char** argv, int function(string[]) vmain)
{

	// Currently all the init that is needed for the GC.
	vrt_gc_init();
	allocDg = vrt_gc_get_alloc_dg();

	auto args = new string[](argc);
	for (size_t i = 0; i < args.length; i++) {
		args[i] = unsafeToString(argv[i]);
	}

	int ret;
	try {
		vrt_run_global_ctors();
		ret = vmain(args);
		vrt_run_global_dtors();
	} catch (Throwable t) {
		// For lack of T.classinfo
		auto ti = **cast(TypeInfo[]**)t;
		char[][3] msgs;
		msgs[0] = cast(char[])"Uncaught exception";
		msgs[1] = cast(char[])ti[ti.length - 1].mangledName;
		msgs[2] = cast(char[])t.msg;

		vrt_panic(cast(char[][])msgs, t.throwFile, t.throwLine);
	}

	vrt_gc_shutdown();

	return ret;
}

string unsafeToString(const(char)* str)
{
	auto start = str;
	while (*str) {
		str++;
	}
	auto len = cast(size_t)str - cast(size_t)start;
	return (cast(immutable(char)*)start)[0 .. len];
}
