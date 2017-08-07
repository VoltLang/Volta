// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
// Written by hand from documentation.
/*!
 * @ingroup cbind
 * @ingroup stdcbind
 */
module core.c.stddef;

version (CRuntime_All):


/*!
 * Windows wchar is different from *NIXs.
 * @{
 */
version (Windows) {

	alias wchar_t  = u16;

} else {

	alias wchar_t  = i32;

}
/*!
 * @}
 */
