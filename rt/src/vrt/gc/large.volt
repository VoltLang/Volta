// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * Holds the code for managing large blocks.
 */
module vrt.gc.large;

import vrt.gc.extent;


struct Large
{
public:
	extent: Extent;


public:
	fn setup(ptr: void*, n: size_t, finalizer: bool, pointers: bool)
	{
		extent.setupLarge(ptr:ptr, n:n, finalizer:finalizer,
		                  pointers:pointers);
	}

	@property fn hasPointers() bool
	{
		return cast(bool)((extent.mData & Extent.PointersMask) >> Extent.PointersShift);
	}

	@property fn hasFinalizer() bool
	{
		return cast(bool)((extent.mData & Extent.FinalizerMask) >> Extent.FinalizerShift);
	}

	@property fn isMarked() bool
	{
		return cast(bool)((extent.mData & Extent.MarkedMask) >> Extent.MarkedShift);
	}

	@property fn mark(val: bool)
	{
		extent.mData = ((extent.mData & ~Extent.MarkedMask) | (val << Extent.MarkedShift));
	}
}
