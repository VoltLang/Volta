// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
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
		return extent.hasPointers;
	}

	@property fn hasFinalizer() bool
	{
		return extent.hasFinalizer;
	}

	@property fn isMarked() bool
	{
		return cast(bool)((extent.data & Extent.MarkedMask) >> Extent.MarkedShift);
	}

	@property fn mark(val: bool)
	{
		extent.data = ((extent.data & ~Extent.MarkedMask) | (val << Extent.MarkedShift));
	}
}
