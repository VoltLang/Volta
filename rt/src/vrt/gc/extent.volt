// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * Holds the code for managing extents.
 */
module vrt.gc.extent;

import vrt.gc.util;
import rb = vrt.gc.rbtree;


/**
 * Metadata about a single region of user allocated memory.
 */
struct Extent
{
public:
	node: rb.Node;
	size_t mData;
	size_t mN;

public:
	enum size_t SlabShift = cast(size_t)0;
	enum size_t SlabMask = cast(size_t)1 << SlabShift;
	enum size_t PointersShift = cast(size_t)1;
	enum size_t PointersMask = cast(size_t)1 << PointersShift;
	enum size_t FinalizerShift = cast(size_t)2;
	enum size_t FinalizerMask = cast(size_t)1 << FinalizerShift;
	enum size_t MarkedShift = cast(size_t)3;
	enum size_t MarkedMask = cast(size_t)1 << MarkedShift;
	enum size_t DataMask = SlabMask | PointersMask | FinalizerMask | MarkedMask;

public:
	fn setupSlab(ptr: void*, n: size_t, finalizer: bool, pointers: bool)
	{
		gcAssert((cast(size_t)ptr & DataMask) == 0);

		mData = cast(size_t)ptr | true << SlabShift |
			finalizer << FinalizerShift | pointers << PointersShift;
		mN = n;
	}

	fn setupLarge(ptr: void*, n: size_t, finalizer: bool, pointers: bool)
	{
		gcAssert((cast(size_t)ptr & DataMask) == 0);

		mData = cast(size_t)ptr | false << SlabShift |
			finalizer << FinalizerShift | pointers << PointersShift;
		mN = n;
	}

	@property fn ptr() void*
	{
		return cast(void*)(mData & ~DataMask);
	}

	@property fn size() size_t
	{
		return mN;
	}

	@property fn min() size_t
	{
		return mData & ~DataMask;
	}

	@property fn max() size_t
	{
		return (mData & ~DataMask) + mN;
	}

	@property fn isSlab() bool
	{
		return cast(bool)((mData & SlabMask) >> SlabShift);
	}

	@property fn isLarge() bool
	{
		return !cast(bool)((mData & SlabMask) >> SlabShift);
	}

	@property fn pointerType() bool
	{
		return cast(bool)((mData & PointersMask) >> PointersShift);
	}
}
