// Copyright 2015-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module vrt.os.gtors;

extern @mangledName("__V_global_ctors") global globalConstructors: fn()[];
extern @mangledName("__V_global_dtors") global globalDestructors: fn()[];
extern @mangledName("__V_local_ctors") global localConstructors: fn()[];
extern @mangledName("__V_local_dtors") global localDestructors: fn()[];


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
