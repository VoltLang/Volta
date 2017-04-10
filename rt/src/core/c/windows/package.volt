// Copyright © 2013-2017, Bernard Helyer.
// See copyright notice in src/watt/licence.volt (BOOST ver 1.0).
/**
 * Windows bindings module that imports everything.
 */
module core.c.windows;

version (Windows):

public import core.c.windows.windows;
public import core.c.windows.wgl;
public import core.c.windows.vk;
