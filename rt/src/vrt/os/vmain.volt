// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.vmain;



version (!Metal):

/**
 * While we could name this main and have the mangler renamit to vmain,
 * it wont work since we don't support overloaded functions.
 */
extern(C) int vmain(object.string[] args);

/**
 * Main entry point, calls vmain.
 */
extern(C) int main(int argc, char** argv)
{
	return object.vrt_run_main(argc, argv, vmain);
}
