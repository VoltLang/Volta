// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.c.stddef;


version(!Metal):

/**
 * Windows wchar is different from *NIXs.
 * @{
 */
version (Windows) {

	alias wchar_t  = u16;

} else {

	alias wchar_t  = u32;

}
/**
 * @}
 */
