// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
/*!
 * This file contains type aliases needed to interface with C code.
 *
 * Even if the current target does not interface with any C code, like
 * standalone linux target, certain OS types are defined to the same as
 * C types. Make this the one true place where they are defined.
 */
module core.c.config;


/*!
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
/*!
 * @}
 */
