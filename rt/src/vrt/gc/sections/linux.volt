// Copyright © 2016, Bernard Helyer.  All rights reserved.
// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.sections.linux;

version (Linux):

import vrt.gc.util;


global sections: const(void*)[][2];

fn initSections()
{
	sections[0] = bssRange();
	sections[1] = dataRange();
}


private:

extern (C) {
	global extern __data_start: u8;
	global extern edata: u8;
	global extern __bss_start: u8;
	global extern end: u8;
	global extern __tbss_start: u8;
}

fn dataRange() const(void*)[]
{
	length := cast(size_t)&edata - cast(size_t)&__data_start;
	return makeRange((cast(void*)&__data_start)[0 .. length]);
}

fn bssRange() const(void*)[]
{
	length := cast(size_t)&end - cast(size_t)&__bss_start;
	return makeRange((cast(void*)&__bss_start)[0 .. length]);
}
