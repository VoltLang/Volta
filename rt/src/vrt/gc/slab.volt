// Copyright 2016-2017, Amaury Séchet.
// Copyright 2016-2017, Bernard Helyer.
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Stuct and code for sub-allocating data from a memory extent.
 */
module vrt.gc.slab;

import core.object : Object;

import vrt.gc.util;
import vrt.gc.extent;
import dsgn = vrt.gc.design;


/*!
 * Return the log2 of the next highest power of two size (or itself if pot).
 *
 *     Size -> Order
 *     2 GB -> 31
 *     1 GB -> 30
 *   512 MB -> 29
 *   256 MB -> 28
 *   128 MB -> 27
 *     .
 *     .
 *     .
 *    32 B  -> 5
 *    16 B  -> 4
 *     8 B  -> 3
 *     4 B  -> 2
 *     2 B  -> 1
 *     1 B  -> 0
 */
fn sizeToOrder(n: size_t) u8
{
	pot := cast(u32)nextHighestPowerOfTwo(n);
	return cast(u8)countTrailingZeros(pot, true);
}

fn orderToSize(order: u8) size_t
{
	return 1U << order;
}

/*!
 * Multiple smaller user memory allocations.
 *
 * You can find the memory that this represents in the extent.memory field.
 */
struct Slab
{
public:
	enum MaxSlots = dsgn.SlabMaxAllocations;

	alias Alignment = Extent.Alignment;

	enum NumElems = 16;
	enum NumBitsPerElm = 8 * typeid(u32).size;

	// Hardcoded assumptions.
	static assert(NumElems == 16);
	static assert(MaxSlots == NumBitsPerElm * NumElems);


public:
	/// Base 'class' for Slab.
	extent: Extent;

	bitmap: u32[16];
	marked: u32[16];
	header: u16;
	freeSlots: u16;
	order: u8;

	/// To help the arena have lists of slabs.
	next: Slab*;


public:
	fn setup(order: u8, memory: void*, finalizer: bool, pointer:bool, internal:bool)
	{
		size := orderToSize(order);
		extent.setupSlab(ptr:memory, n:size * MaxSlots,
		                 finalizer:finalizer,
		                 pointers:pointer,
		                 internal:internal);
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
	fn allocate() u32
	{
		gcAssert(freeSlots > 0);

		hindex := countTrailingZeros(header, true);

		gcAssert(bitmap[hindex] != 0);
		bindex := countTrailingZeros(bitmap[hindex], true);

		// Use xor so we don't need to invert bits.
		// It is ok as we assert the bit is unset before.
		bitmap[hindex] ^= (1 << bindex);

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
			check := current.next;
			if (check.freeSlots > current.freeSlots) {
				*destination = check;
				tmp := check.next;
				check.next = current;
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
		if (obj !is null && hasFinalizer) {
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

	@property fn hasPointers() bool
	{
		return extent.hasPointers;
	}

	@property fn hasFinalizer() bool
	{
		return extent.hasFinalizer;
	}
}

@mangledName("llvm.cttz.i32")
fn countTrailingZeros(bits: u32, isZeroUndef: bool) u32;
