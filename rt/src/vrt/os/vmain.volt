// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.vmain;

import object;
import vrt.ext.stdc : strlen;


extern(C) int vrt_run_main(int argc, char** argv, int function(string[]) vmain)
{

	// Currently all the init that is needed for the GC.
	vrt_gc_init();
	allocDg = vrt_gc_get_alloc_dg();

	auto args = new string[](argc);
	for (size_t i = 0; i < args.length; i++) {
		args[i] = cast(immutable(char)[]) argv[i][0 .. strlen(argv[i])];
	}

	int ret;
	try {
		vrt_run_global_ctors();
		ret = vmain(args);
		vrt_run_global_dtors();
	} catch (Throwable t) {
		// For lack of T.classinfo
		auto ti = **cast(object.TypeInfo[]**)t;
		auto name = ti[ti.length - 1].mangledName;
		auto msg = t.msg;

		object.vrt_printf("%.*s:%i Uncaught exception\n%.*s: %.*s\n",
			cast(int)t.throwFile.length, t.throwFile.ptr,
			cast(int)t.throwLine,
			cast(int)name.length, name.ptr,
			cast(int)msg.length, msg.ptr);

		ret = -1;
	}

	vrt_gc_shutdown();

	return ret;
}

extern(C) void vrt_run_global_ctors()
{
	auto mod = moduleInfoRoot;
	while (mod !is null) {
		foreach (fn; mod.ctors) {
			fn();
		}
		mod = mod.next;
	}
}

extern(C) void vrt_run_global_dtors()
{
	auto mod = moduleInfoRoot;
	while (mod !is null) {
		foreach (fn; mod.dtors) {
			fn();
		}
		mod = mod.next;
	}
}

version (!Metal):

/**
 * While we could name this main and have the mangler renamit to vmain,
 * it wont work since we don't support overloaded functions.
 */
extern(C) int vmain(string[] args);

/**
 * Main entry point, calls vmain.
 */
extern(C) int main(int argc, char** argv)
{
	return vrt_run_main(argc, argv, vmain);
}
