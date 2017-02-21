// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.sections.osx;

version (OSX):

import vrt.gc.util;


global sections: const(void*)[][];

fn initSections()
{
	_dyld_register_func_for_add_image(__osx_on_add_image);
}


private:

alias intptr_t = i64;

struct mach_header_64 {}

struct section_64
{
	sectname:  char[16];
	segname:   char[16];
	addr:      ulong;
	size:      ulong;
	offset:    uint;
	align_:    uint;
	reloff:    uint;
	nreloc:    uint;
	flags:     uint;
	reserved1: uint;
	reserved2: uint;
	reserved3: uint;
}

/// Global store for sections.
global privStore: const(void*)[][512];
/// Global count of sections.
global privCount: size_t;

/// Called on each dynlib image that is loaded into exec.
extern(C) fn __osx_on_add_image(mh: const(mach_header_64)*, slide: intptr_t)
{
	addSection(getSection(mh, slide, "__DATA", "__data"));
	addSection(getSection(mh, slide, "__DATA", "__bss"));
	addSection(getSection(mh, slide, "__DATA", "__common"));
}

// Adds a section to the private store and updates the sections global.
fn addSection(section: void[])
{
	if (section.length == 0) {
		return;
	}

	privStore[privCount++] = makeRange(section);
	sections = privStore[0 .. privCount];
}

// Gets a section from the header or returns null if not found.
fn getSection(mh: const(mach_header_64)*, slide: intptr_t,
              segmentName: const(char)*, sectionName: const(char)*) void[]
{
	sect := getsectbynamefromheader_64(mh, segmentName, sectionName);

	if (sect is null || sect.size <= 0) {
		return null;
	}

	addr := cast(void*)sect.addr + slide;
	size := sect.size;
	return addr[0 .. size];
}

extern(C):
fn _dyld_register_func_for_add_image(fn!C (const(mach_header_64)*, intptr_t));

fn getsectbynamefromheader_64(const(mach_header_64)*,
                              const(char)*, const(char)*) const(section_64)*;
