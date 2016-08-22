// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.c.config;


version(!Metal):

/**
 * Volt doesn't have long and unsigned long in the same way
 * that C does, whos typesdefs changes size depending on
 * bitness of the target and of the target os.
 * @{
 */
version (V_P64 && !Windows) {

	alias c_long  = i64;
	alias c_ulong = u64;

} else {

	alias c_long  = i32;
	alias c_ulong = u32;

}
/**
 * @}
 */
