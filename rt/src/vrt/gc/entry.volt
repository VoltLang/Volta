// Copyright 2012-2017, Jakob Bornecrantz.
// Copyright 2013-2017, David Herberth.
// Copyright 2016-2017, Bernard Helyer.
// SPDX-License-Identifier: BSL-1.0
module vrt.gc.entry;

import core.rt.gc : Stats, AllocDg;
import core.rt.format : vrt_format_readable_size;
import vrt.ext.stdc : calloc, free, getenv, printf;
import vrt.gc.design;
import vrt.gc.sbrk;
import vrt.gc.arena;
import vrt.gc.sections;
import vrt.gc.manager;


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
	version (all) {
		arena: Arena*;
	} else {
		arena: SBrk;
	}
}

local heap: GcHeap;

extern(C) fn vrt_gc_init()
{
	initSections();
	heap.arena = Arena.allocArena();
	heap.arena.setup();
}

extern(C) fn vrt_gc_get_stats(out stats: Stats)
{
	heap.arena.getStats(out stats);
}

extern(C) fn vrt_gc_get_alloc_dg() AllocDg
{
	return heap.arena.allocEntry;
}

extern(C) fn vrt_gc_shutdown()
{
	heap.arena.shutdown();
	heap.arena = null;
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

version (CRuntime_All) {

	import core.c.stdio;

	extern(C) fn vrt_gc_print_stats()
	{
		stats: Stats;

		heap.arena.getStats(out stats);

		fn sink(arg: scope const(char)[]) {
			printf("%.*s", cast(u32)arg.length, arg.ptr);
		}

		printf("   collections: %llu\n", cast(u64)stats.num.collections);
		printf("        allocs: %llu\n", cast(u64)stats.num.allocs);
		printf("   classAllocs: %llu\n", cast(u64)stats.num.classAllocs);
		printf("   arrayAllocs: %llu\n", cast(u64)stats.num.arrayAllocs);
		printf("    allocBytes: ");
		vrt_format_readable_size(sink, stats.num.allocBytes);
		printf("\n");
		printf("    arrayBytes: ");
		vrt_format_readable_size(sink, stats.num.arrayBytes);
		printf("\n");
		printf("    classBytes: ");
		vrt_format_readable_size(sink, stats.num.classBytes);
		printf("\n");
		printf("    zeroAllocs: %llu\n", cast(u64)stats.num.zeroAllocs);

		printf(" slotsMemTotal: ");
		vrt_format_readable_size(sink, stats.slots.memTotal);
		printf("\n");
		printf(" slotsMemLarge: ");
		vrt_format_readable_size(sink, stats.slots.memLarge);
		printf("\n");
		printf("slotsMemCached: ");
		vrt_format_readable_size(sink, stats.slots.memCached);
		printf("\n");
		printf("  slotsMemUsed: ");
		vrt_format_readable_size(sink, stats.slots.memUsed);
		printf("\n");

		foreach (i, count; stats.slots.free[3 .. 13]) {
			order := i + 3;
			num := (1 << order) * count;
			printf("cached:%10u (%4i) ", count, 1 << order);
			vrt_format_readable_size(sink, num);
			printf("\n");
		}

		foreach (i, count; stats.slots.used[3 .. 13]) {
			order := i + 3;
			num := (1 << order) * count;
			printf("used:%12u (%4i) ", count, 1 << order);
			vrt_format_readable_size(sink, num);
			printf("\n");
		}
	}
}
