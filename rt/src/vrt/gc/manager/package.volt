// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * This module selects the appropriate Manager to use.
 */
module vrt.gc.manager;


static import vrt.gc.manager.gigaman;
static import vrt.gc.manager.rbman;

alias Manager = vrt.gc.manager.gigaman.GigaMan;
