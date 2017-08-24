// Copyright © 2012-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module core.rt.gc;

import core.typeinfo;


/**
 * This is all up in the air. But here is how its intended to work.
 *
 * @param typeinfo The type to which we should allocate storage for.
 * @param count the number of elements in a array, minus two if just the type.
 *
 * The count logic is a bit odd. If count is minus two we are allocating the
 * storage for just the type alone, if count is greater then one we are
 * allocating the storage an array of that type. If it is zero the allocDg
 * call MUST return null. Here how it is done,
 * Thow following shows what happends for some cases.
 *
 * For primitive types:
 * int* ptr = new int;
 * int* ptr = allocDg(typeid(int), cast(size_t)-2);
 * // Alloc size == int.sizeof == 4
 *
 * While for arrays:
 * int[] arr; arr.length = 5;
 * int[] arr; { arr.ptr = allocDg(typeid(int), 5); arr.length = 5 }
 * // Alloc size == int.sizeof * 5 == 20
 *
 * Classes are weird, tho in the normal case not so much but notice the -1.
 * Clazz foo = new Clazz();
 * Clazz foo = allocDg(typeid(Clazz), cast(size_t)-1);
 * // Alloc size == Clazz.storage.sizeof
 *
 * Here its where it gets weird: this is because classes are references.
 * Clazz foo = new Clazz;
 * Clazz foo = allocDg(typeid(Clazz), cast(size_t)-2);
 * // Alloc size == (void*).sizeof
 *
 * And going from that this makes sense.
 * Clazz[] arr; arr.length = 3;
 * Clazz[] arr; { arr.ptr = allocDg(typeid(Clazz), 3); arr.length = 3 }
 * // Alloc size == (void*).sizeof * 3
 *
 * And for zero.
 * Clazz[] arr; arr.length = 0;
 * Clazz[] arr; { arr.ptr = allocDg(typeid(Clazz), 0); arr.length = 0 }
 * // Alloc size == (void*).sizeof * 0
 */
alias AllocDg = dg (typeinfo: TypeInfo, count: size_t) void*;
local allocDg: AllocDg;

//! Stats structs for the GC, may change often so no API/ABI stability.
struct Stats
{
	//! Counters, always available.
	struct Num
	{
		collections: u64;
		allocs: u64;
		allocBytes: u64;
		arrayAllocs: u64;
		arrayBytes: u64;
		classAllocs: u64;
		classBytes: u64;
		zeroAllocs: u64;
	}

	//! Slots stats, may not be set for all GCs.
	struct Slot
	{
		//! Memory in large extents.
		memLarge: u64;
		//! Memory cached in slabs.
		memCached: u64;
		//! Memory used in slabs.
		memUsed: u64;
		//! Total memory: used or cached.
		memTotal: u64;

		free: u32[16];
		used: u32[16];
	}

	//! Counters.
	num: Num;
	//! Slots stats.
	slots: Slot;
}

extern(C):

/*!
 * Initialise the GC.
 */
fn vrt_gc_init();
/*!
 * Get an instance of the `AllocDg` delegate.
 */
fn vrt_gc_get_alloc_dg() AllocDg;
/*!
 * Perform a collection.
 */
fn vrt_gc_collect();
/*!
 * Shutdown the GC, call all destructors, free all memory.
 */
fn vrt_gc_shutdown();
/*!
 * Fill out a given `Stats` struct.
 */
fn vrt_gc_get_stats(out stats: Stats) Stats*;
/*!
 * Print out GC stats.
 */
version (CRuntime_All) fn vrt_gc_print_stats();
