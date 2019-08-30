// Copyright 2016-2017, Bernard Helyer.
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * GigaMan reserves a gigabyte of memory and allocates slabs from that using
 * a buddy allocator.
 */
module vrt.gc.manager.gigaman;

import core.object;

import vrt.gc.mman;
import vrt.gc.slab;
import vrt.gc.util;
import vrt.gc.large;
import vrt.gc.errors;
import vrt.gc.rbtree;
import vrt.gc.extent;
import vrt.gc.linkednode;
import vrt.gc.manager.pagetable;
import vrt.ext.stdc;


struct GigaMan
{
private:
	/**
	 * Start the GigaMan struct with the PageTable.
	 *
	 * This means that the arena will be at the start of the
	 * 1G memory region that we manage.
	 */
	mPageTable: PageTable;
	void* mReservedBase;

	mTotalSize: size_t;
	mSlabStruct: Slab*;
	mAllocCache: void[];
	mLowestPointer: void*;
	mHighestPointer: void*;
	mTotalArenaSize: size_t;

	mExtents: LinkedNode*;  // Every extent we allocate, external and internal.


public:
	fn setup(totalArenaSize: size_t)
	{
		gcAssert(totalArenaSize > typeid(GigaMan).size);
		mPageTable.setup(totalArenaSize);
		mTotalArenaSize = totalArenaSize;
	}

	// Call dlg on every extent allocated by this manager.
	fn treeVisit(dlg: RBTree.VisitDg)
	{
		current := mExtents;
		while (current !is null) {
			dlg(cast(Node*)current);
			current = current.next;
		}
	}

	// If ln is present in the extents list, remove it.
	fn remove(ln: LinkedNode*)
	{
		if (mExtents is ln) {
			mExtents = ln.next;
		}
		if (ln.prev !is null) {
			ln.prev.next = ln.next;
		}
		if (ln.next !is null) {
			ln.next.prev = ln.prev;
		}
	}

	fn treeInsert(n: UnionNode*, compare: RBTree.CompDg)
	{
		ln := cast(LinkedNode*)n;
		gcAssert(ln.prev is null);
		gcAssert(ln.next is null);

		if (mExtents !is null) {
			mExtents.prev = ln;
			ln.next = mExtents;
		}
		mExtents = ln;
	}

	fn getExtentFromPtr(ptr: void*) Extent*
	{
		e := getExtent(ptr);
		if (e !is null && e.isInternal) {
			return null;
		}
		return e;
	}

	/**
	 * Return the total size of memory allocated by this GC.
	 * Freeing a Slab's slot won't change this value unless the
	 * backing extent is freed.
	 */
	fn totalSize() size_t
	{
		return mTotalSize;
	}

	/**
	 * Call this function if you expect to call getExtentFromPtr.
	 */
	fn prepareForCollect()
	{
		setLowestPointer();
		setHighestPointer();
	}

	fn shutdown()
	{
		// This is simple, just unmap the whole range.
		pages_unmap(cast(void*)&this, PageTable.TotalSize);
	}


	/*
	 *
	 * Allocate
	 *
	 */

	/// Allocates a struct for a Slab extent.
	/// associatedPtr and associatedSz is the memory that will be managed by the slab. (allocated beforehand)
	fn allocSlabStruct(associatedPtr: void*, associatedSz: size_t) Slab*
	{
		/// Return memory for a Slab, sets mSlabStruct to null if empty.
		fn internalAlloc() Slab*
		{
			i := mSlabStruct.allocate();
			ptr := mSlabStruct.slotToPointer(i);
			if (mSlabStruct.freeSlots == 0) {
				mSlabStruct = null;
			}
			s := cast(Slab*)ptr;
			s.extent.node.linked.prev = null;
			s.extent.node.linked.next = null;
			markPages(associatedPtr, cast(void*)s, associatedSz);
			return s;
		}

		// Easy peasy.
		if (mSlabStruct !is null) {
			return internalAlloc();
		}

		// Here we solve the chicken and egg problem; the slab manages itself.
		order := sizeToOrder(typeid(Slab).size);
		sizeOfOSAlloc := orderToSize(order) * 512;
		memory := allocMemoryFromOS(sizeOfOSAlloc);
		if (memory is null) {
			return null;
		}
		slab := cast(Slab*)memory;
		slab.setup(order:order, memory:memory, finalizer: false, pointer:false, internal:true);

		// Mark the first slot as used, this slab resides
		// there, because it manages itself.
		i := slab.allocate();

		// So we can free from this slab.
		markPages(memory, cast(void*)slab, sizeOfOSAlloc);

		// Now we know mSlabStruct is not null, alloc from it.
		mSlabStruct = slab;
		return internalAlloc();
	}

	/// Allocates a struct for a Large extent.
	fn allocLargeStruct(associatedPtr: void*, associatedSz: size_t) Large*
	{
		return cast(Large*)allocSlabStruct(associatedPtr, associatedSz);
	}

	local fn allocGC(sz: size_t) void*
	{
		memory := pages_reserve(null, PageTable.TotalSize);

		retval := pages_commit(memory, sz);
		if (!retval) {
			panicFailedToAlloc(sz);
		}

		return memory;
	}


	/*
	 *
	 * Free
	 *
	 */

	/// Free a struct and memory for a slab extent.
	fn freeSlabStructAndMem(slab: Slab*, shutdown: bool = false)
	{
		mTotalSize -= slab.extent.size;
		if (!shutdown) {
			remove(&slab.extent.node.linked);
		}
		freeMemoryToOS(slab.extent.ptr, slab.extent.size);
		freeInternalStruct(slab);
	}

	/// Free a struct and memory for a Large extent.
	fn freeLargeStructAndMem(large: Large*, shutdown: bool = false)
	{
		mTotalSize -= large.extent.size;
		if (!shutdown) {
			remove(&large.extent.node.linked);
		}
		freeMemoryToOS(large.extent.ptr, large.extent.size);
		freeInternalStruct(cast(Slab*)large);
	}

	/// Free a struct for a Slab extent.
	fn freeInternalStruct(slab: Slab*)
	{
		ptr := cast(void*)slab;
		e := getExtent(ptr);
		gcAssert(e !is null);
		gcAssert(e.isSlab);
		gcAssert(e.isInternal);

		holder := cast(Slab*)e;
		index := holder.pointerToSlot(ptr);

		holder.free(cast(u32)index);

		// Does this holder hold more then itself?
		if (holder.usedSlots > 1) {
			return;
		}

		if (mSlabStruct is holder) {
			mSlabStruct = null;
		}

		// Free the holder and the memory it manages.
		// But since the holder lives in the memory it manages
		// we only need to free the managed memory, easy.
		freeMemoryToOS(holder.extent.ptr, holder.extent.size);
	}

	/*
	 *
	 * OS memory allocation functions.
	 *
	 */
	/**
	 * Allocates a chunk of memory from the OS.
	 */
	fn allocMemoryFromOS(n: size_t) void*
	{
		if (!mPageTable.canAlloc(n)) {
			return null;
		}
		mTotalSize += n;
		pageIndex := mPageTable.allocIndex(n);
		gcAssert(PageTable.pageIndexToRelative(pageIndex) != 0);
		base := cast(void*)(cast(size_t)&this + PageTable.pageIndexToRelative(pageIndex));
		retval := pages_commit(base, n);
		if (!retval) {
			panicFailedToAlloc(n);
		}
		gcAssert(cast(size_t)base >= (cast(size_t)&this + mTotalArenaSize));
		return base;
	}

	fn freeMemoryToOS(ptr: void*, n: size_t)
	{
		rel := mPageTable.globalToRelative(ptr);
		pageIndex := PageTable.relativeToPageIndex(rel);
		mPageTable.free(pageIndex, n);
		pages_uncommit(ptr, n);
		unmarkPages(ptr, n);
	}


	/*
	 *
	 * RBTree helpers.
	 *
	 */

	fn setLowestPointer()
	{
		mLowestPointer = cast(void*)&this;
	}

	fn setHighestPointer()
	{
		mHighestPointer = cast(void*)(cast(size_t)&this + PageTable.TotalSize);
	}

	/**
	 * Use the page entries to find what extent a given pointer belongs to.
	 * Returns: a pointer to the extent, or null on failure.
	 */
	fn getExtent(ptr: void*) Extent*
	{
		if (ptr is null) {
			return null;
		}
		if (!mPageTable.inBounds(ptr)) {
			return null;
		}
		/* Get the page this pointer belongs to.
		 * The internal extent is made up of multiple pages, so this isn't enough.
		 */
		rel := mPageTable.globalToRelative(ptr);
		prel := PageTable.pageIndexToRelative(PageTable.relativeToPageIndex(rel));
		pptr := cast(void*)(cast(size_t)&this + prel);
		/* Now we have the page, we can lookup the offset from the extent, stored
		 * when this extent was created.
		 */
		p := mPageTable.getPageEntryPtr(pptr);
		if (p is null || *p == 0) {
			return null;
		}
		e := cast(Extent*)PageTable.relativeToGlobal(*p);
		gcAssert(mPageTable.inBounds(cast(void*)e));
		if (!mPageTable.inBounds(cast(void*)e)) {
			return null;
		}
		return e;
	}

	fn compareExtent(n1: Node*, n2: Node*) i32
	{
		// We assume extents don't overlap,
		// so only need to sort on starting address.
		p1 := (cast(Extent*)n1).min;
		p2 := (cast(Extent*)n2).min;
		return p1 < p2 ? -1 : cast(i32)(p1 > p2);
	}

	fn alwaysHit(Node*, Node*) int
	{
		return 0;
	}

	/// Does n contain an empty Slab?
	fn emptySlab(n: Node*) bool
	{
		s := cast(Slab*)n;
		return s.freeSlots > 0;
	}

private:
	/**
	 * For each page allocated, set the offset to the extent as its page entry.
	 * Params:
	 *   memory: a pointer to memory allocated from allocMemoryFromOS, the pages of which we want to mark.
	 *   slab: the pointer to which we want the marked offset to point.
	 *   n: the size of the memory allocated, in bytes.
	 * The offset is slab - pagetable, so &pagetable + offset should return slab.
	 */
	fn markPages(memory: void*, slab: void*, n: size_t)
	{
		gcAssert(n % PageTable.PageSize == 0);
		pages := n / PageTable.PageSize;
		foreach (i; 0u .. pages) {
			ptr := cast(void*)(cast(size_t)memory + (PageTable.PageSize * i));
			gcAssert(mPageTable.inBounds(ptr));
			offset := cast(PageTable.PageEntryType)mPageTable.globalToRelative(slab);
			mPageTable.setPageEntry(ptr, offset);
		}
	}

	fn unmarkPages(memory: void*, n: size_t)
	{
		gcAssert(n % PageTable.PageSize == 0);
		pages := n / PageTable.PageSize;
		foreach (i; 0u .. pages) {
			ptr := cast(void*)(cast(size_t)memory + (PageTable.PageSize * i));
			gcAssert(mPageTable.inBounds(ptr));
			mPageTable.setPageEntry(ptr, 0);
		}
	}
}
