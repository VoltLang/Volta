// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * Holds documentation and defines for the Volt garbage collector.
 */
module vrt.gc.design;


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

