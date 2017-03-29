// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * A simple buddy allocator, only does tracking of which blocks are free
 */
module vrt.gc.buddy;


/**
 * A buddy allocator with 9 orders and 512 blocks in the last order.
 */
struct Buddy512
{
public:
	enum NumLevels = 9u;

private:
	enum OffsetBits = 0xFF_FC00;
	enum OffsetMask = 0x00_03FF;
	enum NumBits = (1u << (NumLevels+1)) - 1u;
	enum NumBytes = NumBits / 8u + 1u;

	mBitmap: u8[NumBytes];
	mNumFree: u32[NumLevels];


public:
	fn setup()
	{
		// Mark the first order and first index as free.
		free(0, 0);
	}

	// Returns true if the buddy allocator can allocate from this order.
	fn canAlloc(order: u32) bool
	{
		if (mNumFree[order] > 0) {
			return true;
		}
		return order == 0 ? false : canAlloc(order-1);
	}

	// One block from the given order, may split orders above to make room.
	// It does no error checking so make sure you can alloc from a given
	// order with canAlloc before calling this function.
	fn alloc(order: u32) u32
	{
		if (mNumFree[order] > 0) {
			return takeFree(order);
		}

		base := alloc(order-1) * 2;
		setBit(indexOf(order, base+1));
		mNumFree[order]++;
		return base;
	}

	// Free one block of the given order and index. Will merge any buddies.
	// As with all of the other functions don't call if you are certain
	// you can free the block that is given to this function.
	fn free(order: u32, n: u32)
	{
		index := indexOf(order, n);
		buddy := index + 1 - (2 * (n % 2));

		// Either the top order or the buddy is not set.
		if (order == 0 || !getBit(buddy)) {
			mNumFree[order]++;
			setBit(index);
			return;
		}

		// Buddy is also set: allocate it, merge it and
		// propegate up to the next order.
		clearBit(buddy);
		mNumFree[order]--;
		free(order-1, n >> 1);
	}


private:
	fn getBit(index: u32) bool
	{
		return cast(bool)(mBitmap[index / 8] >> (index % 8) & 1);
	}

	fn setBit(index: u32)
	{
		mBitmap[index / 8] |= cast(u8)(1 << (index % 8));
	}

	fn clearBit(index: u32)
	{
		// Use xor so we don't need to invert bits.
		// If the bit is not set this will cause a error.
		mBitmap[index / 8] ^= cast(u8)(1 << (index % 8));
	}

	fn takeFree(order: u32) u32
	{
		start := offsetOfOrder(order);
		end := start + numBitsInOrder(order);

		foreach (i; start .. end) {
			if (getBit(i)) {
				clearBit(i);
				mNumFree[order]--;
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
		return (OffsetBits >> (NumLevels - 1 - order)) & OffsetMask;
	}

	static fn numBitsInOrder(order: u32) u32
	{
		return 1 << order;
	}
}

/*
fn dump(ref b: Buddy512)
{
	foreach (i; 0u .. NumLevels) {
		printf("% 5i: ", b.mNumFree[i]);
		start := Buddy512.offsetOfOrder(i);
		end := start + Buddy512.numBitsInOrder(i);
		foreach (j; start .. end) {
			printf(b.getBit(j) ? "1".ptr : "0".ptr);
		}
		printf("\n");
	}
}
*/
