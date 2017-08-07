// Copyright © 2013-2017, Bernard Helyer.
// See copyright notice in src/volt/licence.d (BOOST ver 1.0).
/*!
 * Windows bindings module that imports all other windows modules.
 *
 * @ingroup cbind
 * @ingroup winbind
 */
module core.c.windows;

/*!
 * @defgroup winbind Windows Bindings
 *
 * The windows bindings.
 *
 * @ingroup cbind
 */

version (Windows):

public import core.c.windows.windows;
public import core.c.windows.wgl;
public import core.c.windows.vk;
public import core.c.windows.winhttp;