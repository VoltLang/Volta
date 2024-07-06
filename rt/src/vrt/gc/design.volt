// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Holds documentation and defines for the Volt garbage collector.
 */
module vrt.gc.design;

import core.rt.gc : Stats;

public import vrt.vacuum.defines;


/+

In Volt there can be multiple instances of the garbage collector (from here on
refered to as GC), each being seperate enough that collection in one does not
effect the others. Each instance of a GC is called Arena. It allocates memory
from the OS in groupes of pages called extents. A extent may be futher broken
down into smaller allocations, this is called a slab.

User data allocations are based on size split into small and large classes.

Small: Are sub-allocated from slabs, each slabs contains 512 allocations.
Large: Are directly allocated from the OS and has its own extent.

+/


// The log2 of PageSize - 4KB == 1 << 12
enum PageSizeLog = 12u;

//! The log2 of MinAllocSize - 8B == 1 << 3u
enum MinAllocSizeLog = 3u;

//! The log2 of MaxAllocSize - 128MB == 1 << 27u
enum MaxAllocSizeLog = 27u;

// The log2 of GigaSize - 1GB == 1 << 30
enum GigaSizeLog = 30u;


// Easy to go from log2 to size.
enum PageSize = 1u << PageSizeLog;

// The lower bits of a page address.
enum PageMask = PageSize - 1;

//! Minimum allocation size by which all allocation around rounded up to.
enum MinAllocSize = 1u << MinAllocSizeLog;

//! Safety check for maximum allocation size.
enum MaxAllocSize = 1u << MaxAllocSizeLog;

//! Hardcoded to 2MB for now as we are always on x86.
enum HugePageSize = _2MB;

//! Used to decide the GigaMan allocation size.
enum GigaSize = 1u << GigaSizeLog;

// Hardcoded for now.
enum SlabMaxAllocations = 512;

/*!
 * Internal stat struct, has a lot more statistics then regular
 * but changes more often.
 */
struct InternalStats
{
	base: Stats;

	numFreeSlots: u32[13];
	numUsedSlots: u32[13];
}


/*
 *
 * Checks
 *
 */

// Simple checks because we want these to stay like this.
static assert(_1GB == 1u << GigaSizeLog);
static assert(_128MB == 1u << MaxAllocSizeLog);

/*
 * MinAllocSize is limited by how small that we can fit the total memory
 * managed by the Slab, and that memroy is limited to the page size.
 */
static assert(MinAllocSize >= PageSize / SlabMaxAllocations);
