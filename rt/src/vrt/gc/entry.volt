// Copyright © 2012, Jakob Bornecrantz.  All rights reserved.
// Copyright © 2013, David Herberth.  All rights reserved.
// Copyright © 2016, Bernard Helyer.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.entry;

import core.rt.gc : Stats, AllocDg;
import vrt.ext.stdc : calloc, free, getenv;
import vrt.gc.arena;
import vrt.gc.sections;


/*
 * The naming convention for variables and classes and some general information
 * about the garbage collector.
 *
 * n - Number of bytes.
 * count - Number of item/elements.
 * foosz - The size of a data structure, for malloc.
 * length - Do not use.
 */

struct GcHeap
{
	arena: Arena;
}

local heap: GcHeap;
global stats: Stats;

extern(C) fn vrt_gc_init()
{
	initSections();
	heap.arena.setup();
}

extern(C) fn vrt_gc_get_stats(out res: Stats)
{
	res = stats;
}

extern(C) fn vrt_gc_get_alloc_dg() AllocDg
{
	return heap.arena.allocEntry;
}

extern(C) fn vrt_gc_shutdown()
{
	heap.arena.shutdown();
}

extern(C) fn vrt_gc_collect()
{
	heap.arena.collect();
}

extern(C) fn vrt_gc_total_size() size_t
{
	// TODO: Multiple threads?
	return heap.arena.totalSize();
}
