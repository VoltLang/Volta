// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.vmain;

import core.rt.misc : vrt_run_main;



version (!Metal):

/**
 * While we could name this main and have the mangler renamit to vmain,
 * it wont work since we don't support overloaded functions.
 */
extern(C) fn vmain(args : string[]) i32;

/**
 * Main entry point, calls vmain.
 */
extern(C) fn main(argc : i32, argv : char**) i32
{
	return vrt_run_main(argc, argv, vmain);
}
