// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.gc;

static import object;


alias AllocDg = object.AllocDg;
alias allocDg = object.allocDg;

struct Stats
{
	ulong count;
}

extern(C):

void vrt_gc_init();
AllocDg vrt_gc_get_alloc_dg();
void vrt_gc_shutdown();
Stats* vrt_gc_get_stats(out Stats stats);
