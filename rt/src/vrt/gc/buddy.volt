// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * A simple buddy allocator, only does tracking of which blocks are free
 */
module vrt.gc.buddy;


/**
 * A buddy allocator with 512 blocks in the last order.
 */
struct Buddy512
{
public:
	enum MinOrder = 3u;
	enum MaxOrder = 9u;
	enum NumLevels = MaxOrder - MinOrder + 1;


private:
	alias ElmType = u8;
	enum NumBitsPerElm = 8u;
	enum NumBits = (1u << (MaxOrder+1)) - (1 << MinOrder);
	enum NumElems = NumBits / NumBitsPerElm;

	mBitmap: ElmType[NumElems];
	mNumFree: u32[NumLevels];


public:
	fn setup()
	{
		// For "buddy := index ^ 1;"
		assert(MinOrder > 0);
		// Just to be safe.
		assert(NumBitsPerElm == (1 << MinOrder));

		// Mark the first order and first index as free.
		mBitmap[0] = cast(ElmType)-1;
		mNumFree[0] = numBitsInOrder(MinOrder);
	}

	// Returns true if the buddy allocator can allocate from this order.
	fn canAlloc(order: u32) bool
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
	fn alloc(order: u32) u32
	{
		if (mNumFree[order - MinOrder] > 0) {
			return takeFree(order);
		}

		base := alloc(order-1) * 2;
		setBit(indexOf(order, base+1));
		addFree(order);
		return base;
	}

	// Free one block of the given order and index. Will merge any buddies.
	// As with all of the other functions don't call if you are certain
	// you can free the block that is given to this function.
	fn free(order: u32, n: u32)
	{
		index := indexOf(order, n);
		buddy := index ^ 1;

		// Either the top order or the buddy is not set.
		if (order == MinOrder || !getBit(buddy)) {
			addFree(order);
			setBit(index);
			return;
		}

		// Buddy is also set: allocate it, merge it and
		// propegate up to the next order.
		clearBit(buddy);
		subFree(order);
		free(order-1, n >> 1);
	}


private:
	fn addFree(order: u32)
	{
		mNumFree[order - MinOrder]++;
	}

	fn subFree(order: u32)
	{
		mNumFree[order - MinOrder]--;
	}

	fn getBit(index: u32) bool
	{
		elmIndex := index / NumBitsPerElm;
		bitIndex := index % NumBitsPerElm;

		return cast(bool)(mBitmap[elmIndex] >> bitIndex & 1);
	}

	fn setBit(index: u32)
	{
		elmIndex := index / NumBitsPerElm;
		bitIndex := index % NumBitsPerElm;

		mBitmap[elmIndex] |= cast(ElmType)(1 << bitIndex);
	}

	fn clearBit(index: u32)
	{
		elmIndex := index / NumBitsPerElm;
		bitIndex := index % NumBitsPerElm;

		// Use xor so we don't need to invert bits.
		// If the bit is not set this will cause a error.
		mBitmap[elmIndex] ^= cast(ElmType)(1 << (bitIndex));
	}

	fn takeFree(order: u32) u32
	{
		start := offsetOfOrder(order);
		end := start + numBitsInOrder(order);

		foreach (i; start .. end) {
			if (getBit(i)) {
				clearBit(i);
				subFree(order);
				return i - start;
			}
		}
		assert(false);
	}

	static fn indexOf(order: u32, n: u32) u32
	{
		return offsetOfOrder(order) + n;
	}

	static fn offsetOfOrder(order: u32) u32
	{
		return (1 << order) - (1 << MinOrder);
	}

	static fn numBitsInOrder(order: u32) u32
	{
		return 1 << order;
	}
}

/*
fn dump(ref b: Buddy512)
{
	foreach (i; MinOrder .. MaxOrder+1) {
		printf("%i: (% 5i) ", i, b.mNumFree[i-MinOrder]);
		start := Buddy512.offsetOfOrder(i);
		end := start + Buddy512.numBitsInOrder(i);
		foreach (j; start .. end) {
			printf(b.getBit(j) ? "1".ptr : "0".ptr);
		}
		printf("\n");
	}
}
*/
