// Copyright © 2016-2017, Bernard Helyer.
// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.arena;

import core.typeinfo : TypeInfo;
import core.rt.gc : Stats;
import core.compiler.llvm;
import core.object : Object;

import vrt.os.thread;

import vrt.gc.hit;
import vrt.gc.mman;
import vrt.gc.slab;
import vrt.gc.util;
import vrt.gc.large;
import vrt.gc.entry;
import vrt.gc.design;
import vrt.gc.errors;
import vrt.gc.rbtree;
import vrt.gc.extent;
import vrt.gc.manager;
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

/*!
 * An Arena is an instance of the GC.
 */
struct Arena
{
private:
	// The manager needs to be placed at the start of the Arena.
	mManager: Manager;
	mNum: Stats.Num;


public:
	// 0 would be 1 bytes, 1 would be 2, 2 4, 3 8, etc.
	freeSlabs: Slab*[13];
	freePointerSlabs: Slab*[13];
	usedSlabs: Slab*[13];


	stackBottom: void*;

	hits: HitStack;
	removes: HitStack;


protected:
	mNextCollection: size_t;  // If totalSize is greater than this, a collection will trigger.
	mMultiplicationFactor: double; // mTotalSize * this == mNextCollection.


public:
	local fn allocArena() Arena*
	{
		return cast(Arena*)Manager.allocGC(typeid(Arena).size);
	}

	fn setup()
	{
		stackBottom = vrt_get_stack_bottom();
		mManager.setup(typeid(Arena).size);

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

		hits.free();
		removes.free();

		mManager.shutdown();
	}

	fn getStats(out stats: Stats)
	{
		counter: NodeMemCounter;
		mManager.treeVisit(counter.count);

		stats.num = mNum;
		stats.slots = counter.slots;
	}

	fn allocEntry(typeinfo: TypeInfo, count: size_t) void*
	{
		size: size_t;
		memory: void*;
		registerFinalizer := false;

		if (count == 0) {
			mNum.zeroAllocs++;
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

		// Align to pointer sizes.
		if (size < MinAllocSize) {
			size = MinAllocSize;
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
/*
		printf("pow %i\n", nextHighestPowerOfTwo(size));
*/

		// Statistics
		mNum.allocs++;
		mNum.allocBytes += size;
		if (count == cast(size_t) -1) {
			mNum.classAllocs++;
			mNum.classBytes += size;
		} else if (count > 0) {
			mNum.arrayAllocs++;
			mNum.arrayBytes += size;
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
		mNum.collections++; // Stats

		hits.reset();
		removes.reset();
		mManager.treeVisit(unmark);
		mManager.prepareForCollect();

		__vrt_push_registers(scanStack);
		foreach (section; sections) {
			scanRange(section);
		}

		{
			current := hits.top();
			while (current !is null) {
				hits.pop();

				if (!current.extent.isSlab) {
					scanLarge(cast(Large*) current.extent);
				} else {
					slab := cast(Slab*)current.extent;
					scanSlab(slab, current.ptr);
				}

				current = hits.top();
			}
		}

		mManager.treeVisit(freeIfUnmarked);

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
			// Free empty slabs on the used list.
			current := usedSlab;
			destination: Slab** = &usedSlabs[i];
			while (current !is null) {
				next := current.next;
				if (current.freeSlots > 0) {
					if (current.usedSlots > 0) {
						pushFreeSlab(current.order, current);
					} else if (current.usedSlots == 0) {
						mManager.freeSlabStructAndMem(current);
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
		return mManager.totalSize();
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
		e := checkPtr(ptr);
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
		if (large.hasFinalizer) {
			obj := cast(Object)large.extent.ptr;
			gcAssert(obj !is null);
			obj.__dtor();
		}
		mManager.freeLargeStructAndMem(large);
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
		return scanRange(range);
	}

	fn scanSlab(s: Slab*, ptr: const(void*)) bool
	{
		size := orderToSize(s.order);
		size /= typeid(void*).size;
		vpp := cast(void**) ptr;
		return scanRange(vpp[0 .. size]);
	}

	fn scanLarge(l: Large*) bool
	{
		size := l.extent.size;
		size /= typeid(void*).size;
		vpp := cast(void**) l.extent.ptr;
		return scanRange(vpp[0 .. size]);
	}

	fn scanRange(range: const(void*)[]) bool
	{
		newPtr := false;
		foreach (ptr; range) {
			if (scan(cast(void*)ptr)) {
				newPtr = true;
			}
		}
		return newPtr;
	}

	/**
	 * Given a pointer sized number ptr, treat it as a live pointer,
	 * and mark any Extents that it points at as live.
	 */
	fn scan(ptr: void*) bool
	{
		e := checkPtr(cast(void*)ptr);
		if (e is null) {
			return false;
		}
		if (e.isSlab) {
			return scanHit(ptr, cast(Slab*)e);
		} else {
			return scanHit(ptr, cast(Large*)e);
		}
	}

	fn scanHit(ptr: void*, slab: Slab*) bool
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

	fn scanHit(ptr: void*, large: Large*) bool
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
	fn alloc(n: size_t, hasFinalizer: bool, hasPointer: bool) void*
	{
		if (n <= 4096U) {
			return allocSmall(n, hasFinalizer, hasPointer);
		} else {
			return allocLarge(n, hasFinalizer, hasPointer);
		}
	}

	fn maybeTriggerCollection()
	{
		totSize := mManager.totalSize();

		if (totSize == 0) {
			return;
		}
		if (mNextCollection == 0) {
			mNextCollection = cast(size_t)(totSize * mMultiplicationFactor);
			return;
		}
		if (mNextCollection < totSize) {
			collect();
			mNextCollection = cast(size_t)(totSize * mMultiplicationFactor);
			if (mMultiplicationFactor < MULTIPLICATION_FACTOR_MAX) {
				mMultiplicationFactor += MULTIPLICATION_FACTOR_INCREMENT;
			}
		}
	}

	fn allocSmall(n: size_t, hasFinalizer: bool, hasPointer: bool) void*
	{
		order := sizeToOrder(n);
		size := orderToSize(order);

		// See if there is a slab in the
		// cache, create one if there isn't.
		slab := hasPointer ? freePointerSlabs[order] : freeSlabs[order];
		if (slab is null) {
			maybeTriggerCollection();
			slab = hasPointer ? freePointerSlabs[order] : freeSlabs[order];
			// Check to see if the collection made room at this order.
			if (slab is null) {
				// Otherwise, allocate a new slab.
				slab = allocSlab(order, hasPointer);
				pushFreeSlab(order, slab);
			}
		}

		// Get the element.
		elem := slab.allocate(hasFinalizer);

		// If the cache is empty, remove it from the cache.
		if (slab.freeSlots == 0) {
			popFreeSlab(order, hasPointer);
		}

		return &slab.extent.ptr[elem * size];
	}

	fn pushFreeSlab(order: u8, slab: Slab*)
	{
		if (slab.extent.pointerType) {
			slab.next = freePointerSlabs[order];
			freePointerSlabs[order] = slab;
		} else {
			slab.next = freeSlabs[order];
			freeSlabs[order] = slab;
		}
	}

	fn popFreeSlab(order: u8, hasPointer: bool)
	{
		slab: Slab*;
		if (hasPointer) {
			slab = freePointerSlabs[order];
			freePointerSlabs[order] = freePointerSlabs[order].next;
		} else {
			slab = freeSlabs[order];
			freeSlabs[order] = freeSlabs[order].next;
		}
		slab.next = usedSlabs[order];
		usedSlabs[order] = slab;
	}

	fn allocLarge(n: size_t, hasFinalizer: bool, hasPointer: bool) void*
	{
		// Do this first so we don't accidentally free the memory
		// we just allocated. Also allocMemoryFromOS might grab
		// a just recently freed memory region.
		maybeTriggerCollection();

		// Grab memory from the OS.
		memorysz := roundUpToPageSize(n);
		memory := mManager.allocMemoryFromOS(memorysz);
		if (memory is null) {
			collect();
			memory = mManager.allocMemoryFromOS(memorysz);
			if (memory is null) {
				panicFailedToAlloc(memorysz);
			}
		}

		// Grab a Large struct to hold metadata about the extent.
		large := mManager.allocLargeStruct(memory, memorysz);

		large.setup(ptr:memory, n:memorysz, finalizer:hasFinalizer,
		            pointers:hasPointer);
		mManager.treeInsert(&large.extent.node, compareExtent);

		return large.extent.ptr;
	}

	fn allocSlab(order: u8, hasPointer: bool) Slab*
	{
		// Grab memory from the OS.
		memorysz := orderToSize(order) * 512;
		memory := mManager.allocMemoryFromOS(memorysz);
		if (memory is null) {
			collect();
			memory = mManager.allocMemoryFromOS(memorysz);
			if (memory is null) {
				panicFailedToAlloc(memorysz);
			}
		}

		// Grab a Slab struct to hold metadata about the slab.
		slab := mManager.allocSlabStruct(memory, memorysz);

		// Finally setup the slab and return.
		slab.setup(order:order, memory:memory, pointer:hasPointer, internal:false);

		mManager.treeInsert(&slab.extent.node, compareExtent);

		return slab;
	}


private:
	/*
	 *
	 * Stats counting.
	 *
	 */

	//! Helper struct for stats counting.
	static struct NodeMemCounter
	{
		slots: Stats.Slot;

		fn count(n: Node*)
		{
			e := cast(Extent*)n;
			used: u64;
			cached: u64;

			slots.memTotal += e.size;
			if (e.isSlab) {
				slab := cast(Slab*)e;

				slots.free[slab.order] += slab.freeSlots;
				slots.used[slab.order] += slab.usedSlots;

				used += slab.usedSlots * (1u << slab.order);
				cached += slab.freeSlots * (1u << slab.order);

				slots.memCached += cached;
				slots.memUsed += used;
			} else {
				slots.memLarge += e.size;
			}
		}
	}


	/*
	 *
	 * Pointer checking code.
	 *
	 */

	fn checkPtr(ptr: void*) Extent*
	{
		return mManager.getExtentFromPtr(ptr);
	}


	/*
	 *
	 * Extent tree helpers.
	 *
	 */

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

	///a Does n contain an empty Slab?
	fn emptySlab(n: Node*) bool
	{
		s := cast(Slab*)n;
		return s.freeSlots > 0;
	}
}
