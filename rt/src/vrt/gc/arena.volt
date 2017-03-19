// Copyright © 2016-2017, Bernard Helyer.
// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.arena;

import core.typeinfo : TypeInfo;
import core.rt.gc : Stats;
import core.rt.misc : vrt_panic;
import core.compiler.llvm;
import core.object : Object;

import vrt.ext.stdc : printf, snprintf;

import vrt.os.thread;
import vrt.gc.hit;
import vrt.gc.mman;
import vrt.gc.slab;
import vrt.gc.util;
import vrt.gc.large;
import vrt.gc.entry;
import vrt.gc.rbtree;
import vrt.gc.extent;
import vrt.gc.sections;


extern (C) {
	version (Windows && V_P32 || OSX) {
		@mangledName("_vrt_push_registers")
		fn __vrt_push_registers(dg() bool) bool;
	} else {
		fn __vrt_push_registers(dg() bool) bool;
	}
}

/* The multiplication factor is the point at which if the total number
 * of bytes allocated goes over it times the size after the last collection,
 * a GC collection will be triggered.
 */
/// The initial value of the multiplication factor.
enum float MULTIPLICATION_FACTOR_ORIGIN    = 1.5f;
/// The multiplication factor will not be increased beyond this value.
enum float MULTIPLICATION_FACTOR_MAX       = 25.0f;
/// The amount the multiplication factor increases after every collection.
enum float MULTIPLICATION_FACTOR_INCREMENT = 0.1f;

/**
 * An Arena is an instance of the GC.
 */
struct Arena
{
public:
	// 0 would be 1 bytes, 1 would be 2, 2 4, 3 8, etc.
	freeSlabs: Slab*[13];
	freePointerSlabs: Slab*[13];
	usedSlabs: Slab*[13];

	// All of the extents in a tree, ordered by memory address of the
	// allocation. This gives use O(log n) lookup from user address to
	// to extent info.
	extents: RBTree;
	internalExtents: RBTree;

	stackBottom: void*;

	hits: HitStack;
	removes: HitStack;


protected:
	mTotalSize: size_t;
	mNextCollection: size_t;  // If totalSize is greater than this, a collection will trigger.
	mMultiplicationFactor: double; // mTotalSize * this == mNextCollection.
	mLowestPointer: void*;
	mHighestPointer: void*;
	mSlabStruct: Slab*;
	mAllocCache: void[];


public:
	fn setup()
	{
		stackBottom = vrt_get_stack_bottom();
		mMultiplicationFactor = MULTIPLICATION_FACTOR_ORIGIN;
		hits.init();
		removes.init();
	}

	/**
	 * Called when the process hosting the runtime is shutting down.
	 * Release all memory, and clean up.
	 */
	fn shutdown()
	{
		/* Free everything still in use.
		 * This isn't redundant, even if this process is closing, as
		 * some memory may have associated destructors.
		 */
		foreach (freeSlab; freeSlabs) {
			if (freeSlab !is null) {
				freeSlab.freeAll();
			}
		}
		foreach (freeSlab; freePointerSlabs) {
			if (freeSlab !is null) {
				freeSlab.freeAll();
			}
		}
		foreach (usedSlab; usedSlabs) {
			if (usedSlab !is null) {
				usedSlab.freeAll();
			}
		}
		// We don't just use visit/free(Extent*) because the tree might rotate.
		node := extents.extractAny(compareExtent);
		while (node !is null) {
			e := cast(Extent*)node;
			if (e.isLarge) {
				l := cast(Large*)e;
				if (l.hasFinalizer) {
					obj := cast(Object)e.ptr;
					gcAssert(obj !is null);
					obj.__dtor();
				}
			}

			freeMemoryToOS(e.ptr, e.size);
			if (e.isSlab) {
				freeSlabStruct(cast(Slab*)e);
			} else {
				freeLargeStruct(cast(Large*)e);
			}

			node = extents.extractAny(compareExtent);
		}

		hits.free();
		removes.free();
		// Clean up anything left in the alloc cache.
		if (mAllocCache.ptr !is null) {
			pages_unmap(mAllocCache.ptr, mAllocCache.length);
			mAllocCache = null;
		}
	}

	fn allocEntry(typeinfo: TypeInfo, count: size_t) void*
	{
		size: size_t;
		memory: void*;
		registerFinalizer := false;

		if (count == 0) {
			stats.numZeroAllocs++;
			return null;
		} else if (count == cast(size_t) -2) {
			size = typeinfo.size;
		} else if (count == cast(size_t) -1) {
			// Hack for now.
			size = typeinfo.classSize;
			// We have a class and we want its dtor to be called.
			registerFinalizer = true;
		} else {
			size = count * typeinfo.size;
		}

		// viviv ctfe/020 fails if we don't do this.
		if (size < 16) {
			size = 16;
		}

/*
		str := typeinfo.mangledName;
		if (count == cast(size_t) -2) {
			printf("      '%.*s'\n", cast(int)str.length, str.ptr);
		} else if (count == cast(size_t) -1) {
			printf("C     '%.*s'\n", cast(int)str.length, str.ptr);
		} else {
			printf("array '%.*s'\n", cast(int)str.length, str.ptr);
		}
*/

		// Statistics
		stats.numAllocs++;
		stats.numAllocBytes += size;
		if (count == cast(size_t) -1) {
			stats.numClassAllocs++;
			stats.numClassBytes += size;
		} else if (count > 0) {
			stats.numArrayAllocs++;
			stats.numArrayBytes += size;
		}

		memory = alloc(size, registerFinalizer, typeinfo.mutableIndirection);
		gcAssert(memory !is null);

		if (count == cast(size_t) -1) {
			__llvm_memcpy(memory, typeinfo.classInit, typeinfo.classSize, 0, false);
		} else {
			__llvm_memset(memory, 0, size, 0, false);
		}

		return memory;
	}

	fn collect()
	{
		hits.reset();
		removes.reset();
		extents.visit(unmark);
		setLowestPointer();
		setHighestPointer();

		__vrt_push_registers(scanStack);
		foreach (section; sections) {
			scan(section);
		}

		{
			current := hits.top();
			while (current !is null) {
				hits.pop();

				if (!current.extent.isSlab) {
					scan(current.extent);
				} else {
					slab := cast(Slab*)current.extent;
					size := orderToSize(slab.order);
					scan(current.ptr, size);
				}

				current = hits.top();
			}
		}

		extents.visit(freeIfUnmarked);

		{
			current := removes.top();

			// We can't remove things from the tree in a visit method.
			while (current !is null) {
				gcAssert(current.extent.isLarge);
				free(cast(Large*)current.extent);
				removes.pop();
				current = removes.top();
			}
		}

		foreach (i, freeSlab; freeSlabs) {
			collectSlab(freeSlab);
			freeSlab.makeAllMoreSorted(&freeSlabs[i]);
		}
		foreach (i, freeSlab; freePointerSlabs) {
			collectSlab(freeSlab);
			freeSlab.makeAllMoreSorted(&freePointerSlabs[i]);
		}
		foreach (i, usedSlab; usedSlabs) {
			collectSlab(usedSlab);
			// Free empty used slabs.
			current := usedSlab;
			destination: Slab** = &usedSlabs[i];
			while (current !is null) {
				next := current.next;
				if (current.freeSlots > 0) {
					if (current.usedSlots > 0) {
						pushFreeSlab(current.order, current);
					} else if (current.usedSlots == 0) {
						extents.remove(&current.extent.node, compareExtent);
						mTotalSize -= current.extent.size;
						freeMemoryToOS(current.extent.ptr, current.extent.size);
						freeSlabStruct(current);
					}
					*destination = next;
				} else {
					destination = &current.next;
				}
				current = next;
			}
		}
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

protected:
	fn collectSlab(s: Slab*)
	{
		current := s;
		while (current !is null) {
			foreach (i; 0 .. Slab.MaxSlots) {
				slot := cast(u32)i;
				if (!current.isMarked(slot) && !current.isFree(slot)) {
					current.free(slot);
				}
			}
			current = current.next;
		}
	}

	fn free(ptr: void*)
	{
		e := getExtentFromPtr(ptr);
		if (e is null) {
			return;
		}
		if (e.isSlab) {
			free(ptr, cast(Slab*)e);
		} else {
			// Assume large extent.
			free(cast(Large*)e);
		}
	}

	fn free(large: Large*)
	{
		mTotalSize -= large.extent.size;
		if (large.hasFinalizer) {
			obj := cast(Object)large.extent.ptr;
			gcAssert(obj !is null);
			obj.__dtor();
		}
		extents.remove(&large.extent.node, compareExtent);

		freeMemoryToOS(large.extent.ptr, large.extent.size);
		freeLargeStruct(large);
	}

	fn free(ptr: void*, s: Slab*)
	{
		s.freePointer(ptr);
	}

	fn scanStack() bool
	{
		p: const(void*);

		iptr := cast(size_t)&p;
		iend := cast(size_t)stackBottom;
		length := (iend - iptr) / typeid(size_t).size;

		range := (&p)[1 .. length];
		return scan(range);
	}

	fn scan(range: const(void*)[]) bool
	{
		newPtr := false;
		foreach (ptr; range) {
			if (scan(cast(void*)ptr)) {
				newPtr = true;
			}
		}
		return newPtr;
	}

	fn scan(e: Extent*) bool
	{
		return scan(e.ptr, e.size);
	}

	/**
	 * Given a pointer ptr to a block of memory n bytes long,
	 * scan that area of memory as if it were a block of pointers.
	 */
	fn scan(ptr: void*, n: size_t) bool
	{
		ptrsz := typeid(void*).size;
		newPtr := false;
		/* Scan every byte of the range that could fit a pointer, as a pointer.
		 * Example: if n is 7, scan ranges 0..4, 1..5, 2..6, and 3..7 as pointers.
		 */
		for (i: size_t = 0; i <= n - ptrsz; i += 1) {
			ptrptr: void* = *cast(void**)(cast(size_t)ptr + i);
			if (scan(ptrptr)) {
				newPtr = true;
			}
		}
		return newPtr;
	}

	/**
	 * Given a pointer sized number ptr, treat it like a live pointer,
	 * and mark any Extents that it points at as live.
	 */
	fn scan(ptr: void*) bool
	{
		e := checkPtr(cast(void*)ptr);
		if (e is null) {
			return false;
		}
		if (e.isSlab) {
			return scan(ptr, cast(Slab*)e);
		} else {
			return scan(ptr, cast(Large*)e);
		}
	}

	fn scan(ptr: void*, slab: Slab*) bool
	{
		/* Ensure we scan the whole slot, regardless of where the user's
		 * pointer points to in the range.
		 */
		ptr = slab.pointerToSlotStart(ptr);

		if (slab.isMarked(ptr)) {
			return false;
		}
		slab.markChild(ptr);
		extent := cast(Extent*)slab;
		if (extent.pointerType) {
			hl := hits.add();
			hl.extent = extent;
			hl.ptr = ptr;
		}
		return true;
	}

	fn scan(ptr: void*, large: Large*) bool
	{
		if (large.isMarked) {
			return false;
		}
		large.mark = true;
		if (large.extent.pointerType) {
			hl := hits.add();
			hl.extent = &large.extent;
			hl.ptr = cast(void*)ptr;
		}
		return true;
	}

	/**
	 * Allocate n bytes of memory, and return a pointer to it.
	 */
	fn alloc(n: size_t, finalizer: bool, pointer: bool) void*
	{
		if (n <= 4096U) {
			return allocSmall(n, finalizer, pointer);
		} else {
			return allocLarge(n, finalizer, pointer);
		}
	}

	fn maybeTriggerCollection()
	{
		if (mTotalSize == 0) {
			return;
		}
		if (mNextCollection == 0) {
			mNextCollection = cast(size_t)(mTotalSize * mMultiplicationFactor);
			return;
		}
		if (mNextCollection < mTotalSize) {
			collect();
			mNextCollection = cast(size_t)(mTotalSize * mMultiplicationFactor);
			if (mMultiplicationFactor < MULTIPLICATION_FACTOR_MAX) {
				mMultiplicationFactor += MULTIPLICATION_FACTOR_INCREMENT;
			}
		}
	}

	fn allocSmall(n: size_t, finalizer: bool, pointer: bool) void*
	{
		order := sizeToOrder(n);
		size := orderToSize(order);

		// See if there is a slab in the
		// cache, create if not.
		slab := pointer ? freePointerSlabs[order] : freeSlabs[order];
		if (slab is null) {
			maybeTriggerCollection();
			slab = pointer ? freePointerSlabs[order] : freeSlabs[order];
			// Check to see if the collection made room at this order.
			if (slab is null) {
				// Otherwise, allocate a new slab.
				slab = allocSlab(order, pointer);
				pushFreeSlab(order, slab);
				if (pointer) {
					freePointerSlabs[order] = slab;
				} else {
					freeSlabs[order] = slab;
				}
			}
		}

		// Get the element.
		elem := slab.allocate(finalizer);

		// If the cache is empty, remove it from the cache.
		if (slab.freeSlots == 0) {
			popFreeSlab(order, pointer);
		}

		return &slab.extent.ptr[elem * size];
	}

	fn pushFreeSlab(order: size_t, slab: Slab*)
	{
		if (slab.extent.pointerType) {
			slab.next = freePointerSlabs[order];
			freePointerSlabs[order] = slab;
		} else {
			slab.next = freeSlabs[order];
			freeSlabs[order] = slab;
		}
	}

	fn popFreeSlab(order: size_t, pointer: bool)
	{
		slab: Slab*;
		if (pointer) {
			slab = freePointerSlabs[order];
			freePointerSlabs[order] = freePointerSlabs[order].next;
		} else {
			slab = freeSlabs[order];
			freeSlabs[order] = freeSlabs[order].next;
		}
		slab.next = usedSlabs[order];
		usedSlabs[order] = slab;
	}

	fn allocLarge(n: size_t, _finalizer: bool, pointer: bool) void*
	{
		// Do this first so we don't accedentily free the memory
		// we just allocated. Also allocMemoryFromOS might grab
		// a just recently freed memory region.
		maybeTriggerCollection();

		// Grab memory from the OS.
		memorysz := roundUpToPageSize(n);
		memory := allocMemoryFromOS(memorysz);

		// Grab a Large struct to hold metadata about the extent.
		large := allocLargeStruct();

		large.setup(ptr:memory, n:memorysz, finalizer:_finalizer,
		            pointers:pointer);
		extents.insert(&large.extent.node, compareExtent);

		return large.extent.ptr;
	}

	fn allocSlab(order: u8, pointer:bool) Slab*
	{
		// Grab memory from the OS.
		memorysz := orderToSize(order) * 512;
		memory := allocMemoryFromOS(memorysz);

		// Grab a Slab struct to hold metadata about the slab.
		slab := allocSlabStruct();

		// Finally setup the slab and return.
		slab.setup(cast(u8)order, memory, pointer);

		extents.insert(&slab.extent.node, compareExtent);

		return slab;
	}


private:
	/*
	 *
	 * Struct alloc functions.
	 *
	 */

	/// Allocates a struct for a Slab extent.
	fn allocSlabStruct() Slab*
	{
		/// Returns memory for a Slab, sets mSlabStrut to null if empty.
		fn internalAlloc() Slab*
		{
			i := mSlabStruct.allocate(finalizer:false);
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
		slab.setup(order, memory, false);

		// Mark that the first slot is used, as it resides
		// there, because Slab manages itself.
		i := slab.allocate(finalizer:false);

		// So we can free from this slab.
		internalExtents.insert(&slab.extent.node, compareExtent);

		// Now we know mSlabStruct is not null, alloc from it.
		mSlabStruct = slab;
		return internalAlloc();
	}

	/// Free a struct for a Slab extent.
	fn freeSlabStruct(slab: Slab*)
	{
		ptr := cast(void*)slab;
		e := getExtentFromPtr(ptr, internalExtents);
		gcAssert(internalExtents.root !is null);
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
		internalExtents.remove(&holder.extent.node, compareExtent);

		// Incase we are freeing the current cached mSlabStruct
		// or if it is null, find the first mSlabStruct with a
		// free slot and use it.
		if (mSlabStruct is holder ||
		    mSlabStruct is null) {
			mSlabStruct = cast(Slab*)internalExtents.find(emptySlab);
		}

		// Free the holder and the memory it manages.
		// But since the holder lives in the memory it manages
		// we only need to free the managed memory, easy.
		freeMemoryToOS(holder.extent.ptr, holder.extent.size);
	}

	/// Allocates a struct for a Large extent.
	fn allocLargeStruct() Large*
	{
		return cast(Large*)allocSlabStruct();
	}

	/// Free a struct for a Large extent.
	fn freeLargeStruct(large: Large*)
	{
		freeSlabStruct(cast(Slab*)large);
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
			msg: char[64];
			len := snprintf(msg.ptr, msg.length, "Alloc of %llu bytes failed.", cast(u64)n);
			vrt_panic([msg[0 .. len]], __LOCATION__);
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
	 * Pointer checking code.
	 *
	 */

	fn checkPtr(ptr: void*) Extent*
	{
		if (cast(size_t)ptr < cast(size_t)mLowestPointer || cast(size_t)ptr > cast(size_t)mHighestPointer) {
			return null;
		}
		return getExtentFromPtr(ptr);
	}

	fn getExtentFromPtr(ptr: void*) Extent*
	{
		return getExtentFromPtr(ptr, extents);
	}

	fn getExtentFromPtr(ptr: void*, _extents: RBTree) Extent*
	{
		v := cast(size_t)ptr;
		e := cast(Extent*)_extents.root;
		while (e !is null) {
			if (v < e.min) {
				e = cast(Extent*)e.node.left.node;
			} else if (v >= e.max) {
				e = cast(Extent*)e.node.right.node;
			} else {
				return e;
			}
		}

		return null;
	}


	/*
	 *
	 * Extent tree helpers.
	 *
	 */

	fn setLowestPointer()
	{
		e := cast(Extent*)extents.root;
		while (e.node.left.node !is null) {
			e = cast(Extent*)e.node.left.node;
		}
		mLowestPointer = cast(void*)e.min;
	}

	fn setHighestPointer()
	{
		e := cast(Extent*)extents.root;
		while (e.node.right.node !is null) {
			e = cast(Extent*)e.node.right.node;
		}
		mHighestPointer = cast(void*)e.max;
	}

	fn compareExtent(n1: Node*, n2: Node*) i32
	{
		// We assume extents doesn't overlap,
		// so only need to sort on start address.
		p1 := (cast(Extent*)n1).min;
		p2 := (cast(Extent*)n2).min;
		return p1 < p2 ? -1 : cast(i32)(p1 > p2);
	}

	fn unmark(n: Node*)
	{
		e := cast(Extent*)n;
		if (e.isSlab) {
			s := cast(Slab*)e;
			s.clearMarked();
		} else {
			l := cast(Large*)e;
			l.mark = false;
		}
	}

	fn freeIfUnmarked(n: Node*)
	{
		e := cast(Extent*)n;
		if (e.isSlab) {
			return;
		} else {
			l := cast(Large*)e;
			if (l.isMarked) {
				return;
			}

			hl := removes.add();
			hl.extent = e;
		}
	}

	/// Does n contain an empty Slab?
	fn emptySlab(n: Node*) bool
	{
		s := cast(Slab*)n;
		return s.freeSlots > 0;
	}
}
