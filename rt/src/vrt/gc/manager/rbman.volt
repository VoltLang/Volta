// Copyright 2016-2017, Bernard Helyer.
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
/*!
 * This module holds code that mangages allocating memory for extents and
 * memory for the objects in the extents. This manager uses a RBTree to search
 * to search for extents.
 */
module vrt.gc.manager.rbman;

import core.object;

import vrt.gc.mman;
import vrt.gc.slab;
import vrt.gc.util;
import vrt.gc.large;
import vrt.gc.errors;
import vrt.gc.rbtree;
import vrt.gc.extent;
import vrt.gc.linkednode;


/*!
 * Extent manager that uses a RBTree to enable searching of pointers.
 */
struct RBMan
{
private:
	mTotalSize: size_t;
	mSlabStruct: Slab*;
	mAllocCache: void[];
	mLowestPointer: void*;
	mHighestPointer: void*;
	// All of the extents in a tree, ordered by memory address of the
	// allocation. This gives use O(log n) lookup from user address to
	// to extent info.
	mExtents: RBTree;
	mInternalExtents: RBTree;


public:
	fn setup(size: size_t)
	{
	}

	fn treeVisit(dlg: RBTree.VisitDg)
	{
		mExtents.visit(dlg);
	}

	fn treeInsert(n: UnionNode*, compare: RBTree.CompDg)
	{
		mExtents.insert(&n.tree, compare);
	}

	fn getExtentFromPtr(ptr: void*) Extent*
	{
		if (cast(size_t)ptr < cast(size_t)mLowestPointer || cast(size_t)ptr > cast(size_t)mHighestPointer) {
			return null;
		}
		return getExtentFromPtr(ptr, mExtents);
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
		// We don't just use visit/free(Extent*) because the tree might rotate.
		node := mExtents.root;
		while (node !is null) {
			e := cast(Extent*)node;
			if (e.isSlab) {
				freeSlabStructAndMem(cast(Slab*)e);
			} else {
				freeLargeStructAndMem(cast(Large*)e);
			}

			node = mExtents.root;
		}

		// Clean up anything left in the alloc cache.
		if (mAllocCache.ptr !is null) {
			pages_unmap(mAllocCache.ptr, mAllocCache.length);
			mAllocCache = null;
		}

		// Free the manager as well, after this this is invalid.
		pages_unmap(cast(void*)&this, typeid(RBMan).size);
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
		/// Returns memory for a Slab, sets mSlabStrut to null if empty.
		fn internalAlloc() Slab*
		{
			i := mSlabStruct.allocate();
			ptr := mSlabStruct.slotToPointer(i);
			if (mSlabStruct.freeSlots == 0) {
				mSlabStruct = null;
			}
			return cast(Slab*)ptr;
		}

		// Easy peasy.
		if (mSlabStruct !is null) {
			return internalAlloc();
		}

		// Here we solve the chicken and egg problem.
		// So the slab manages itself.
		order := sizeToOrder(typeid(Slab).size);
		sizeOfOSAlloc := orderToSize(order) * 512;
		memory := allocMemoryFromOS(sizeOfOSAlloc);
		slab := cast(Slab*)memory;
		slab.setup(order:order, memory:memory, finalizer:false, pointer:false, internal:true);

		// Mark that the first slot is used, as it resides
		// there, because Slab manages itself.
		i := slab.allocate();

		// So we can free from this slab.
		mInternalExtents.insert(&slab.extent.node.tree, compareExtent);

		// Now we know mSlabStruct is not null, alloc from it.
		mSlabStruct = slab;
		return internalAlloc();
	}

	/// Allocates a struct for a Large extent.
	fn allocLargeStruct(associatedPtr: void*, associatedSz: size_t) Large*
	{
		return cast(Large*)allocSlabStruct(associatedPtr, associatedSz);
	}

	local fn allocGC(n: size_t) void*
	{
		n = roundUpToPageSize(n);
		memory := pages_map(null, n);
		if (memory is null) {
			panicFailedToAlloc(n);
		}
		return memory;
	}


	/*
	 *
	 * Free
	 *
	 */

	/// Free a struct and memory for a slab extent.
	fn freeSlabStructAndMem(slab: Slab*)
	{
		mTotalSize -= slab.extent.size;
		mExtents.remove(&slab.extent.node.tree, compareExtent);
		freeMemoryToOS(slab.extent.ptr, slab.extent.size);
		freeInternalStruct(slab);
	}

	/// Free a struct and memory for a Large extent.
	fn freeLargeStructAndMem(large: Large*)
	{
		mTotalSize -= large.extent.size;
		mExtents.remove(&large.extent.node.tree, compareExtent);
		freeMemoryToOS(large.extent.ptr, large.extent.size);
		freeInternalStruct(cast(Slab*)large);
	}

	/// Free a struct for a Slab extent.
	fn freeInternalStruct(slab: Slab*)
	{
		ptr := cast(void*)slab;
		e := getExtentFromPtr(ptr, mInternalExtents);
		gcAssert(mInternalExtents.root !is null);
		gcAssert(e !is null);
		gcAssert(e.isSlab);

		holder := cast(Slab*)e;
		index := holder.pointerToSlot(ptr);

		holder.free(cast(u32)index);

		// Does this holder hold more then itself?
		if (holder.usedSlots > 1) {
			return;
		}

		// Remove the holder from the tree.
		mInternalExtents.remove(&holder.extent.node.tree, compareExtent);

		// Incase we are freeing the current cached mSlabStruct
		// or if it is null, find the first mSlabStruct with a
		// free slot and use it.
		if (mSlabStruct is holder ||
		    mSlabStruct is null) {
			mSlabStruct = cast(Slab*)mInternalExtents.find(emptySlab);
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
		/* We're not concerned if this came from a cache or not,
		 * mark it against mTotalSize regardless.
		 */
		mTotalSize += n;
		if (n == mAllocCache.length) {
			ptr := mAllocCache.ptr;
			mAllocCache = null;
			return ptr;
		}

		memory := pages_map(null, n);
		if (memory is null) {
			panicFailedToAlloc(n);
		}
		return memory;
	}

	fn freeMemoryToOS(ptr: void*, n: size_t)
	{
		if (mAllocCache.ptr !is null) {
			pages_unmap(mAllocCache.ptr, mAllocCache.length);
		}
		mAllocCache = ptr[0 .. n];
	}


	/*
	 *
	 * RBTree helpers.
	 *
	 */

	fn setLowestPointer()
	{
		e := cast(Extent*)mExtents.root;
		while (e.node.tree.left.node !is null) {
			e = cast(Extent*)e.node.tree.left.node;
		}
		mLowestPointer = cast(void*)e.min;
	}

	fn setHighestPointer()
	{
		e := cast(Extent*)mExtents.root;
		while (e.node.tree.right.node !is null) {
			e = cast(Extent*)e.node.tree.right.node;
		}
		mHighestPointer = cast(void*)e.max;
	}

	fn getExtentFromPtr(ptr: void*, _extents: RBTree) Extent*
	{
		v := cast(size_t)ptr;
		e := cast(Extent*)_extents.root;
		while (e !is null) {
			if (v < e.min) {
				e = cast(Extent*)e.node.tree.left.node;
			} else if (v >= e.max) {
				e = cast(Extent*)e.node.tree.right.node;
			} else {
				return e;
			}
		}

		return null;
	}

	fn compareExtent(n1: Node*, n2: Node*) i32
	{
		// We assume extents don't overlap,
		// so we only need to sort on the start address.
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
}
