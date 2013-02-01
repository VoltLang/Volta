// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.vmain;

import object;

/**
 * While we could name this main and have the mangler renamit to vmain,
 * it wont work since we don't support overloaded functions.
 */
extern(C) int vmain();

/**
 * Main entry point, calls vmain.
 */
extern(C) int main(int c, char** argv)
{
	// Currently all the init that is needed for the GC.
	vrt_gc_init();
	allocDg = vrt_gc_get_alloc_dg();

	return vmain();
}
