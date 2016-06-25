// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.gc;


struct Stats
{
	ulong count;
}

extern(C):

Stats* vrt_gc_get_stats(out Stats stats);
