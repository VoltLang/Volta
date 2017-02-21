// Copyright © 2016, Amaury Séchet.  All rights reserved.
// Copyright © 2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
/**
 * Stuct and code for sub-allocating data from a memory extent.
 */
module vrt.gc.slab;

import core.object : Object;

import vrt.gc.util;
import vrt.gc.extent;


fn sizeToOrder(n: size_t) u8
{
	pot := cast(u32)nextHighestPowerOfTwo(n);
	return cast(u8)countTrailingZeros(pot, true);
}

fn orderToSize(order: u8) size_t
{
	return 1U << order;
}

/**
 * Multiple smaller user memory allocations.
 *
 * You can find the memory that this represents in the extent.memory field.
 */
struct Slab
{
public:
	enum MaxSlots = 512;


public:
	/// Base 'class' for Slab.
	extent: Extent;

	bitmap: u32[16];
	marked: u32[16];
	finalizer: u32[16];
	header: u16;
	freeSlots: u16;
	order: u8;

	/// To help the arena have lists of slabs.
	next: Slab*;


public:
	fn setup(order: u8, memory: void*, pointer:bool)
	{
		size := orderToSize(order);
		extent.setupSlab(ptr:memory, n:size * MaxSlots,
		                 finalizer:false,
		                 pointers:pointer);
		this.order = order;

		foreach (ref b; bitmap) {
			b = 0xFFFF_FFFFU;
		}
		header = 0xFFFFU;
		freeSlots = cast(u16)(16 * 32);
	}

	/**
	 * Allocate one of the 512 slots of this SmallBlock.
	 * Returns the index of the slot allocated.
	 */
	fn allocate(finalizer: bool) u32
	{
		gcAssert(freeSlots > 0);

		hindex := countTrailingZeros(header, true);

		gcAssert(bitmap[hindex] != 0);
		bindex := countTrailingZeros(bitmap[hindex], true);

		// Use xor so we don't need to invert bits.
		// It is ok as we assert the bit is unset before.
		bitmap[hindex] ^= (1 << bindex);
		markFinalizer(hindex, bindex, finalizer);

		// If we unset all bits, unset header.
		if (bitmap[hindex] == 0) {
			header = cast(u16)(header ^ (1 << hindex));
		}

		freeSlots--;
		return hindex * 32 + bindex;
	}

	/**
	 * Free all slots on this Slab,
	 * and all Slabs on this list.
	 */
	fn freeAll()
	{
		current := &this;
		while (current !is null) {
			foreach (i; 0 .. MaxSlots) {
				slot := cast(u32)i;
				if (!current.isFree(slot)) {
					current.free(slot);
				}
			}
			current = current.next;
		}
	}

	/**
	 * Go through the list of Slabs, moving those with more free slots
	 * closer to the front.
	 */
	fn makeAllMoreSorted(root: Slab**)
	{
		destination := root;
		current := &this;
		while (current !is null && current.next !is null) {
			next := current.next;
			if (next.freeSlots > current.freeSlots) {
				*destination = next;
				tmp := next.next;
				next.next = current;
				current.next = tmp;
				destination = &current.next;
				current = tmp;
			} else {
				destination = &current.next;
				current = current.next;
			}
		}
	}

	fn isFree(bit: u32) bool
	{
		gcAssert(bit < MaxSlots);

		hindex := bit / 32;
		bindex := bit % 32;

		gcAssert(hindex < 16);

		return (bitmap[hindex] & (1 << bindex)) != 0;
	}

	fn free(bit: u32)
	{
		gcAssert(bit < MaxSlots);

		hindex := bit / 32;
		bindex := bit % 32;

		gcAssert(hindex < 16);
		gcAssert(!isFree(bit));

		ptr := slotToPointer(bit);
		obj := cast(Object)ptr;
		if (obj !is null && hasFinalizer(hindex, bindex)) {
			obj.__dtor();
		}

		freeSlots++;
		header = cast(u16)(header | (1 << hindex));
		bitmap[hindex] |= (1 << bindex);
	}

	@property fn usedSlots() u16
	{
		return cast(u16)(MaxSlots - freeSlots);
	}

	fn isMarked(bit: u32) bool
	{
		hindex := bit / 32;
		bindex := bit % 32;
		return (marked[hindex] & (1 << bindex)) != 0;
	}

	fn mark(bit: u32)
	{
		hindex := bit / 32;
		bindex := bit % 32;
		marked[hindex] |= 1 << bindex;
	}

	fn hasFinalizer(hindex: u32, bindex: u32) bool
	{
		return (finalizer[hindex] & (1 << bindex)) != 0;
	}

	fn markFinalizer(hindex: u32, bindex: u32, _finalizer: bool)
	{
		if (_finalizer) {
			finalizer[hindex] |= 1 << bindex;
		} else {
			finalizer[hindex] &= ~(1 << bindex);
		}
	}

	fn isMarked(ptr: void*) bool
	{
		i := pointerToSlot(ptr);
		gcAssert(i >= 0 && i < MaxSlots);
		return isMarked(cast(u32)i);
	}

	fn markChild(ptr: void*)
	{
		i := pointerToSlot(ptr);
		gcAssert(i >= 0 && i < MaxSlots);
		mark(cast(u32)i);
	}

	fn clearMarked()
	{
		foreach (ref m; marked) {
			m = 0;
		}
	}

	// Returns true if the ptr was allocated from this Slab.
	fn isChildPointer(ptr: void*) bool
	{
		return pointerToSlot(ptr) >= 0;
	}

	/**
	 * Given a pointer from this Slab, free its slot.
	 */
	fn freePointer(ptr: void*)
	{
		slot := pointerToSlot(ptr);
		gcAssert(slot >= 0 && slot < MaxSlots);
		free(cast(u32)slot);
	}

	/**
	 * Given a pointer from this Slab, return a pointer
	 * to the beginning of its address range.
	 */
	fn pointerToSlotStart(ptr: void*) void*
	{
		slot := pointerToSlot(ptr);
		gcAssert(slot >= 0 && slot < MaxSlots);
		return slotToPointer(cast(u32)slot);
	}

	fn slotToPointer(slot: u32) void*
	{
		gcAssert(slot < MaxSlots);
		base := cast(size_t)extent.min;
		sz := orderToSize(order);
		return cast(void*)(base + sz * slot);
	}

	/**
	 * Given a pointer, return its slot index, or < 0.
	 */
	fn pointerToSlot(ptr: void*) i64
	{
		ptrnum := cast(size_t)ptr;
		minaddr := extent.min;
		maxaddr := extent.max;

		// Check if the pointer falls in our extent.
		if (ptrnum < minaddr || ptrnum >= maxaddr) {
			return -1;
		}

		// Calculate the slot index and return it.
		size := orderToSize(order);
		slot := (ptrnum - minaddr) / size;
		gcAssert(slot < MaxSlots);
		return cast(i64)slot;
	}
}

@mangledName("llvm.cttz.i32")
fn countTrailingZeros(bits: u32, isZeroUndef: bool) u32;
