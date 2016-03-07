// Copyright © 2012-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.vacuum.vmain;


extern(C) int vrt_run_main(int argc, char** argv, int function(string[]) vmain)
{

	// Currently all the init that is needed for the GC.
	object.vrt_gc_init();
	object.allocDg = object.vrt_gc_get_alloc_dg();

	auto args = new string[](argc);
	for (size_t i = 0; i < args.length; i++) {
		args[i] = unsafeToString(argv[i]);
	}

	int ret;
	try {
		object.vrt_run_global_ctors();
		ret = vmain(args);
		object.vrt_run_global_dtors();
	} catch (object.Throwable t) {
		// For lack of T.classinfo
		auto ti = **cast(object.TypeInfo[]**)t;
		char[][3] msgs;
		msgs[0] = cast(char[])"Uncaught exception";
		msgs[1] = cast(char[])ti[ti.length - 1].mangledName;
		msgs[2] = cast(char[])t.msg;

		object.vrt_panic(cast(char[][])msgs, t.throwFile, t.throwLine);
	}

	object.vrt_gc_shutdown();

	return ret;
}

string unsafeToString(const(char)* str)
{
	auto start = str;
	while (*str) {
		str++;
	}
	auto len = cast(size_t)str - cast(size_t)start;
	return (cast(immutable(char*))start)[0 .. len];
}
