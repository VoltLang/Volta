// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * Holds documentation and defines for the Volt garbage collector.
 */
module vrt.gc.design;


/**
 * Common sizes for helpers.
 * @{
 */
enum size_t  _2GB = 2u * 1024 * 1024 * 1024;
enum size_t  _1GB = 1u * 1024 * 1024 * 1024;
enum size_t  _2MB =        2u * 1024 * 1024;
enum size_t  _1MB =        1u * 1024 * 1024;
enum size_t _64KB =              64u * 1024;
enum size_t  _4KB =               4u * 1024;
enum size_t  _1KB =               1u * 1024;
/**
 * @}
 */

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


enum PageSizeLog = 12;
enum PageSize    = 1U << PageSizeLog;
enum PageMask    = PageSize - 1;

/// Hardcoded to 2MB for now as we are always on x86.
enum HugePageSize = _2MB;

/// Used to decide the GigaMan allocation size.
enum GigaSize = _1GB;
