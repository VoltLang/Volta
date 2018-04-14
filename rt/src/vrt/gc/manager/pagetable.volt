// Copyright 2016-2017, Bernard Helyer.
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * Companion module to GigaMan, implements the pagetable.
 */
module vrt.gc.manager.pagetable;

import vrt.ext.stdc;

import dsgn = vrt.gc.design;

import vrt.gc.util;
import vrt.gc.slab;
import vrt.gc.rbtree;
import vrt.gc.util.buddy;


/*!
 * This struct implements a 1GB page table. It assumes that it has been placed
 * at the beginning of the memory area that it is managing.
 */
struct PageTable
{
public:
	static assert(GigaBuddy.MaxOrder == 18u);
	static assert(GigaBuddy.MaxNumBits * PageSize == TotalSize);
	static assert(GigaBuddy.MinOrder == 3u);
	static assert(TotalSize / GigaBuddy.MinNumBits == MaximumSize);

	enum size_t MaximumSize = dsgn.MaxAllocSize;
	enum size_t TotalSize = dsgn.GigaSize;
	enum size_t FirstSize = dsgn.HugePageSize;
	enum size_t PageSize = dsgn.PageSize;

	alias PageEntryType = u32;
	enum size_t PageEntrySize = typeid(PageEntryType).size;
	enum size_t PageEntryBits = PageEntrySize * 8;

	enum size_t PageTableNum = TotalSize / PageSize;
	enum size_t PageTableSize = PageTableNum * typeid(PageEntryType).size;

	alias FirstEntryType = u64;
	enum size_t FirstEntrySize = typeid(FirstEntryType).size;
	enum size_t FirstEntryBits = FirstEntrySize * 8;
	enum size_t FirstNumBits = TotalSize / FirstSize;
	enum size_t FirstNum = FirstNumBits / FirstEntryBits;


private:
	// The main page table.
	mPages: PageEntryType[PageTableNum];

	// Buddy allocator for the pages.
	mBuddy: GigaBuddy;

	// Very high level pruning.
	mFirst: FirstEntryType[FirstNum];


public:
	fn setup(totalArenaSize: size_t)
	{
		mBuddy.setup();
		gcAssert(totalArenaSize > typeid(PageTable).size);
		// Reserve the first totalArenaSize bytes
		// out of the PageTable, Manager and Arena.
		pages := (totalArenaSize / PageSize) + 1;
		mBuddy.reserveStart(pages);
	}

	// Returns true if the given global pointer is inside the range of this page table.
	fn inBounds(ptr: void*) bool
	{
		offset := globalToRelative(ptr);
		return offset < TotalSize;
	}

	// Returns true if we can allocate n bytes.
	fn canAlloc(n: size_t) bool
	{
		if (n == 0) {
			return false;
		}
		order := sizeToBuddyOrder(n);
		return n <= TotalSize && mBuddy.canAlloc(order);
	}

	fn free(index: size_t, n: size_t)
	{
		order := sizeToBuddyOrder(n);
		b := pageTableToBuddyIndex(order, index);
		mBuddy.free(order, b);
	}

	// Use the buddy allocator to allocate pages for n bytes, and return the corresponding page index.
	// Check with canAlloc first.
	fn allocIndex(n: size_t) size_t
	{
		order := sizeToBuddyOrder(n);
		retval := mBuddy.alloc(order);
		index := buddyIndexToPageTable(order, retval);
		return index;
	}

	fn getPageEntryPtrFromIndex(index: size_t) PageEntryType*
	{
		ptr := cast(void*)(cast(size_t)&this + pageIndexToRelative(index));
		return getPageEntryPtr(ptr);
	}

	fn getPageEntryPtr(ptr: void*) PageEntryType*
	{
		addr := globalToRelative(ptr);

		// Is the address inside of the giga allocation?
		if (addr > TotalSize) {
			return null;
		}

		// Which first bit should we check.
		bit := relativeToFirstIndex(addr);

		// Check the first level cache.
		if (!checkFirst(bit)) {
			return null;
		}

		// Return the address to the page entry.
		return &mPages[relativeToPageIndex(addr)];
	}

	fn checkFirst(index: size_t) bool
	{
		elmIndex := index / FirstNumBits;
		bitIndex := index % FirstNumBits;

		return cast(bool)(mFirst[elmIndex] >> bitIndex & 1);
	}

	fn setFirst(index: size_t)
	{
		elmIndex := index / FirstNumBits;
		bitIndex := index % FirstNumBits;

		mFirst[elmIndex] |= cast(FirstEntryType)(1UL << bitIndex);
	}

	fn setPageEntry(index: size_t, data: PageEntryType)
	{
		bit := (index * PageSize) / (TotalSize / FirstNumBits);
		setFirst(bit);
		mPages[index] = data;
	}

	fn setPageEntry(ptr: void*, data: PageEntryType)
	{
		rel := globalToRelative(ptr);
		index := relativeToPageIndex(rel);
		setPageEntry(index, data);
	}


	/*
	 *
	 * Address conversion functions.
	 *
	 */

	fn globalToRelative(ptr: void*) size_t
	{
		start := cast(size_t)&this;
		return cast(size_t)ptr - start; // Overflows
	}

	fn relativeToGlobal(rel: size_t) void*
	{
		start := cast(size_t)&this;
		return cast(void*)(rel + start); // Overflows
	}

	/*
	 *
	 * First and page conversion functions.
	 *
	 */

	local fn relativeToPageIndex(addr: size_t) size_t
	{
		return addr / PageSize;
	}

	local fn relativeToFirstIndex(addr: size_t) size_t
	{
		return addr / FirstSize;
	}

	local fn pageIndexToRelative(index: size_t) size_t
	{
		return index * PageSize;
	}

	local fn pageIndexToFirstIndex(index: size_t) size_t
	{
		return relativeToFirstIndex(pageIndexToRelative(index));
	}

	local fn firstIndexToRelative(index: size_t) size_t
	{
		return index * FirstSize;
	}


	/*
	 *
	 * Buddy conversion functions.
	 *
	 */

	global fn pageTableToBuddyIndex(order: size_t, index: size_t) size_t
	{
		return index / (1 << GigaBuddy.MaxOrder - order);
	}

	global fn buddyIndexToPageTable(order: size_t, index: size_t) size_t
	{
		return index * (1 << GigaBuddy.MaxOrder - order);
	}

	global fn sizeToBuddyOrder(n: size_t) size_t
	{
		gcAssert(n >= PageSize);
		return GigaBuddy.MaxOrder - sizeToOrder(n / PageSize);
	}
}
