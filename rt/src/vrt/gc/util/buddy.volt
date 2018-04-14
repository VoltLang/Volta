// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * A simple buddy allocator, only does tracking of which blocks are free
 */
module vrt.gc.util.buddy;

import vrt.gc.util;
import vrt.ext.stdc;


/*!
 * Buddy allocator template with adjustable size and internal element
 * representation.
 */
struct BuddyDefinition!(MIN: size_t, MAX: size_t, T)
{
public:
	enum MinOrder = MIN;
	enum MaxOrder = MAX;
	enum NumLevels = MaxOrder - MinOrder + 1;
	enum MinNumBits = 1 << MinOrder;
	enum MaxNumBits = 1 << MaxOrder;


private:
	alias ElmType = T;
	enum NumBitsPerElm = typeid(ElmType).size * 8u;
	enum NumBits = (1u << (MaxOrder+1)) - (1 << MinOrder);
	enum NumElems = NumBits / NumBitsPerElm;

	mNumFree: size_t[NumLevels];
	mLowestFreeIndex: size_t[NumLevels];
	mBitmap: ElmType[NumElems];


public:
	fn setup()
	{
		// For "buddy := index ^ 1;"
		gcAssert(MinOrder > 0);
		// Just to be safe.
		gcAssert(NumBitsPerElm == (1 << MinOrder));

		// Mark the first order and first index as free.
		mBitmap[0] = cast(ElmType)-1;
		mNumFree[0] = numBitsInOrder(MinOrder);
		mLowestFreeIndex[0] = offsetOfOrder(MinOrder);
	}

	// Reserve n max order blocks from the beginning of memory.
	fn reserveStart(n: size_t)
	{
		foreach (i; 0 .. n) {
			gcAssert(canAlloc(MaxOrder));
			ret := alloc(MaxOrder);
			gcAssert(ret == i);
		}
	}

	// Returns true if the buddy allocator can allocate from this order.
	fn canAlloc(order: size_t) bool
	{
		if (order < MinOrder) {
			return false;
		}
		if (mNumFree[order - MinOrder] > 0) {
			return true;
		}
		return canAlloc(order-1);
	}

	// One block from the given order, may split orders above to make room.
	// It does no error checking so make sure you can alloc from a given
	// order with canAlloc before calling this function.
	fn alloc(order: size_t) size_t
	{
		if (mNumFree[order - MinOrder] > 0) {
			return takeFree(order);
		}

		base := alloc(order-1) * 2;
		free(order, base + 1);
		return base;
	}

	// Free one block of the given order and index. Will merge any buddies.
	// As with all of the other functions don't call if you are certain
	// you can free the block that is given to this function.
	fn free(order: size_t, n: size_t)
	{
		index := indexOf(order, n);
		buddy := index ^ 1;

		// Either the top order or the buddy is not set.
		if (order == MinOrder || !getBit(buddy)) {
			addFree(order);
			setBit(index);
			if (mLowestFreeIndex[order - MinOrder] > index || mNumFree[order - MinOrder] == 1) {
				mLowestFreeIndex[order - MinOrder] = index;
			}
			return;
		}

		// Buddy is also set: allocate it, merge it and
		// propagate up to the next order.
		clearBit(buddy);
		subFree(order);
		free(order-1, n >> 1);
	}


private:
	fn addFree(order: size_t)
	{
		mNumFree[order - MinOrder]++;
	}

	fn subFree(order: size_t)
	{
		mNumFree[order - MinOrder]--;
	}

	fn getBit(index: size_t) bool
	{
		elmIndex := index / NumBitsPerElm;
		bitIndex := index % NumBitsPerElm;

		return cast(bool)(mBitmap[elmIndex] >> bitIndex & 1);
	}

	fn setBit(index: size_t)
	{
		elmIndex := index / NumBitsPerElm;
		bitIndex := index % NumBitsPerElm;

		mBitmap[elmIndex] |= cast(ElmType)(1 << bitIndex);
	}

	fn clearBit(index: size_t)
	{
		elmIndex := index / NumBitsPerElm;
		bitIndex := index % NumBitsPerElm;

		// Use xor so we don't need to invert bits.
		// If the bit is not set this will cause a error.
		mBitmap[elmIndex] ^= cast(ElmType)(1 << (bitIndex));
	}

	fn takeFree(order: size_t) size_t
	{
		startbit := offsetOfOrder(order);
		i := mLowestFreeIndex[order - MinOrder];
		if (getBit(i)) {
			clearBit(i);
			subFree(order);
			mLowestFreeIndex[order - MinOrder] = i ^ 1;
			return i - startbit;
		}
		start := startbit / NumBitsPerElm;
		endbit := startbit + numBitsInOrder(order);
		end := endbit / NumBitsPerElm;

		foreach (ei, ref elm; mBitmap[start .. end]) {
			if (elm == 0) {
				continue;
			}
			i = countLeadingZeros(elm, true) + startbit + ei * NumBitsPerElm;
			clearBit(i);
			subFree(order);
			return i - startbit;
		}
		gcAssert(false);
		return 0;  // Never reached.
	}

	static fn indexOf(order: size_t, n: size_t) size_t
	{
		return offsetOfOrder(order) + n;
	}

	static fn offsetOfOrder(order: size_t) size_t
	{
		return (1 << order) - (1 << MinOrder);
	}

	static fn numBitsInOrder(order: size_t) size_t
	{
		return 1 << order;
	}
}

@mangledName("llvm.cttz.i8")
fn countLeadingZeros(bits: u8, isZeroUndef: bool) u8;


/**
 * A buddy allocator with 512*512 blocks in the last order.
 */
struct GigaBuddy = mixin BuddyDefinition!(3u, 18u, u8);

/*
fn dump(ref b: DumpBuddy)
{
	foreach (i; DumpBuddy.MinOrder .. DumpBuddy.MaxOrder+1) {
		printf("%i: (% 5i) ", i, b.mNumFree[i-DumpBuddy.MinOrder]);
		start := DumpBuddy.offsetOfOrder(i);
		end := start + DumpBuddy.numBitsInOrder(i);
		foreach (j; start .. end) {
			printf(b.getBit(j) ? "1".ptr : "0".ptr);
			foreach (k; 1 .. 1 << (DumpBuddy.MaxOrder - i)) {
				printf(" ");
			}
		}
		printf("\n");
	}
}
*/
