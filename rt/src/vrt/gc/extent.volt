// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/*!
 * Holds the code for managing extents.
 */
module vrt.gc.extent;

import vrt.gc.util;
import vrt.gc.linkednode;
import rb = vrt.gc.rbtree;


/*!
 * Metadata about a single region of user allocated memory.
 */
struct Extent
{
public:
	node: UnionNode;

	enum Kind : u32
	{
		None   = 0x0,
		Ptr    = 0x1,
		Fin    = 0x2,
		PtrFin = 0x3,
	}


private:
	mData: size_t;
	mN: size_t;


public:
	enum size_t SlabShift = 0u;
	enum size_t SlabMask = 1u << SlabShift;
	enum size_t KindShift = 1u;
	enum size_t KindMask = (Kind.Ptr << KindShift) | (Kind.Fin << KindShift);
	enum size_t MarkedShift = 3u; // Kind takes to bits.
	enum size_t MarkedMask = 1u << MarkedShift;
	enum size_t InternalShift = 4u;
	enum size_t InternalMask = 1u << InternalShift;
	enum size_t DataMask = SlabMask | KindMask | MarkedMask | InternalMask;


public:
	global fn makeKind(finalizer: bool, pointers: bool) Kind
	{
		return (finalizer ? Kind.Fin : Kind.None) | (pointers ? Kind.Ptr : Kind.None);
	}

	fn setupSlab(ptr: void*, n: size_t, finalizer: bool, pointers: bool)
	{
		gcAssert((cast(size_t)ptr & DataMask) == 0);

		kind := makeKind(finalizer, pointers);
		mData = cast(size_t)ptr | true << SlabShift | kind << KindShift;
		mN = n;
	}

	fn setupLarge(ptr: void*, n: size_t, finalizer: bool, pointers: bool)
	{
		gcAssert((cast(size_t)ptr & DataMask) == 0);

		kind := makeKind(finalizer, pointers);
		mData = cast(size_t)ptr | false << SlabShift | kind << KindShift;
		mN = n;
	}

	@property fn ptr() void*
	{
		return cast(void*)(mData & ~DataMask);
	}

	@property fn data() size_t
	{
		return mData;
	}

	@property fn data(d: size_t)
	{
		mData = d;
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

	@property fn isInternal() bool
	{
		return cast(bool)((mData & InternalMask) >> InternalShift);
	}

	@property fn isSlab() bool
	{
		return cast(bool)((mData & SlabMask) >> SlabShift);
	}

	@property fn isLarge() bool
	{
		return !cast(bool)((mData & SlabMask) >> SlabShift);
	}

	@property fn kind() Kind
	{
		return cast(Kind)((mData & KindMask) >> KindShift);
	}

	@property fn hasFinalizer() bool
	{
		return (kind & Kind.Fin) != 0;
	}

	@property fn hasPointers() bool
	{
		return (kind & Kind.Ptr) != 0;
	}
}
