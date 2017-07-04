// Copyright © 2015-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.os.gtors;

import core.object: globalConstructors, globalDestructors;


extern(C) fn vrt_run_global_ctors()
{
	foreach (ctor; globalConstructors) {
		ctor();
	}
}

extern(C) fn vrt_run_global_dtors()
{
	foreach (dtor; globalDestructors) {
		dtor();
	}
}
