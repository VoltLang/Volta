// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Module for selecting section.
 */
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
