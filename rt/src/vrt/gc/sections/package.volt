// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.sections;


version (Windows) {
	public import vrt.gc.sections.windows;
} else version (Linux) {
	public import vrt.gc.sections.linux;
} else version (OSX) {
	public import vrt.gc.sections.osx;
} else {
	fn initSections() {}
	global sections: const(void*)[][];
}
