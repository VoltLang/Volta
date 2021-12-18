// Copyright 2016-2017, Bernard Helyer.
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
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
	freePtrSlabs: Slab*[13];
	freeFinSlabs: Slab*[13];
	freePtrFinSlabs: Slab*[13];
	usedSlabs: Slab*;


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
		hits.hitInit();
		removes.hitInit();
	}

	/**
	 * Called when the process hosting the runtime is shutting down.
	 * Release all memory, and clean up.
	 */
	fn shutdown()
	{
		/* Run all finalizers in all objects, we do not free them
		 * and assume that the manager will free all memory.
		 */
		mManager.treeVisit(runAllFinalizers);

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
			// Early out on zero allocs.
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
			// Array allocation.
			size = count * typeinfo.size;
		}

		// Align to pointer sizes.
		if (size < MinAllocSize) {
			size = MinAllocSize;
		}

		// Check max size.
		if (size > MaxAllocSize) {
			vrt_gc_print_stats();
			panicFailedToAlloc(size);
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
		// This allocation should always work.
		memory = alloc(size, registerFinalizer, typeinfo.mutableIndirection);
		gcAssert(memory !is null);

		// Statistics, do this after we have allocated to
		// give better stats if we explode futher in the GC.
		mNum.allocs++;
		mNum.allocBytes += size;
		if (count == cast(size_t) -1) {
			mNum.classAllocs++;
			mNum.classBytes += size;
		} else if (count > 0) {
			mNum.arrayAllocs++;
			mNum.arrayBytes += size;
		}

		// Zero memory or do class init.
		if (count == cast(size_t) -1) {
			__llvm_memcpy(memory, typeinfo.classInit, typeinfo.classSize, 0, false);
		} else {
			// TODO make the GC always return zeroed memory.
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

		foreach (ref slab; freeSlabs) {
			slab = pruneFreeSlabs(slab);
		}
		foreach (ref slab; freePtrSlabs) {
			slab = pruneFreeSlabs(slab);
		}
		foreach (ref slab; freeFinSlabs) {
			slab = pruneFreeSlabs(slab);
		}
		foreach (ref slab; freePtrFinSlabs) {
			slab = pruneFreeSlabs(slab);
		}

		usedSlabs = pruneUsedSlabs(usedSlabs);

		foreach (i, slab; freeSlabs) {
			slab.makeAllMoreSorted(&freeSlabs[i]);
		}
		foreach (i, slab; freePtrSlabs) {
			slab.makeAllMoreSorted(&freePtrSlabs[i]);
		}
		foreach (i, slab; freeFinSlabs) {
			slab.makeAllMoreSorted(&freeFinSlabs[i]);
		}
		foreach (i, slab; freePtrFinSlabs) {
			slab.makeAllMoreSorted(&freePtrFinSlabs[i]);
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
	//! Prune the a free slab list, checking usedSlots and following slab->next.
	fn pruneFreeSlabs(s: Slab*) Slab*
	{
		if (s is null) {
			return null;
		} else if (s.usedSlots > 0) {
			// This slab is still in use.
			s.next = pruneFreeSlabs(s.next);
			return s;
		} else {
			next := s.next;
			s.next = null;

			mManager.freeSlabStructAndMem(s);
			// Don't return this, only next.
			return pruneFreeSlabs(next);
		}
	}

	/*!
	 * Prune the used slab list, checking usedSlots and freeSlots
	 * also following slab->next.
	 */
	fn pruneUsedSlabs(s: Slab*) Slab*
	{
		currentSlab := s;
		while (currentSlab !is null) {
			if (currentSlab.freeSlots == 0) {
				// Is the next one still fully used?
				currentSlab.next = pruneUsedSlabs(currentSlab.next);
				// This is still fully used, return it.
				break;
			} else if (currentSlab.usedSlots == 0) {
				next := currentSlab.next;
				currentSlab.next = null;
				mManager.freeSlabStructAndMem(currentSlab);
				// This was freed, return only next.
				currentSlab = next;
			} else {
				next := currentSlab.next;
				currentSlab.next = null;
				pushFreeSlab(currentSlab);
				// This slab turned into a free slab so return only next.
				currentSlab = next;
			}
		}
		return currentSlab;
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
		// This needs to be a size_t to enforce alignment.
		p: const(size_t) = 0;

		iptr := cast(size_t)&p;
		iend := cast(size_t)stackBottom;
		length := (iend - iptr) / typeid(size_t).size;

		// Also grab the size_t value, needed for LLVM 13 aggresive optimizer.
		range := (&p)[0 .. length];

		return scanRange(cast(void*[])range);
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
		if (slab.hasPointers) {
			hl := hits.add();
			hl.extent = &slab.extent;
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
		if (large.hasPointers) {
			hl := hits.add();
			hl.extent = &large.extent;
			hl.ptr = ptr;
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
		kind := Extent.makeKind(hasFinalizer, hasPointer);
		order := sizeToOrder(n);
		size := orderToSize(order);

		// See if there is a slab in the
		// cache, create one if there isn't.
		slab := getFreeSlab(order, kind);
		if (slab is null) {
			maybeTriggerCollection();
			slab = getFreeSlab(order, kind);

			// Check to see if the collection made room at this order.
			if (slab is null) {
				// Otherwise, allocate a new slab.
				slab = allocSlab(order, hasFinalizer, hasPointer);
				pushFreeSlab(slab);
			}
		}

		// Get the element.
		elem := slab.allocate();

		// If the cache is empty, remove it from the cache.
		if (slab.freeSlots == 0) {
			popFreeSlab(slab);
		}

		return &slab.extent.ptr[elem * size];
	}

	fn getFreeSlab(order: u8, kind: Extent.Kind) Slab*
	{
		final switch (kind) with (Extent.Kind) {
		case None: return freeSlabs[order];
		case Ptr: return freePtrSlabs[order];
		case Fin: return freeFinSlabs[order];
		case PtrFin: return freePtrFinSlabs[order];
		}
	}

	fn pushFreeSlab(slab: Slab*)
	{
		final switch (slab.extent.kind) with (Extent.Kind) {
		case None:
			slab.next = freeSlabs[slab.order];
			freeSlabs[slab.order] = slab;
			break;
		case Ptr:
			slab.next = freePtrSlabs[slab.order];
			freePtrSlabs[slab.order] = slab;
			break;
		case Fin:
			slab.next = freeFinSlabs[slab.order];
			freeFinSlabs[slab.order] = slab;
			break;
		case PtrFin:
			slab.next = freePtrFinSlabs[slab.order];
			freePtrFinSlabs[slab.order] = slab;
			break;
		}
	}

	fn popFreeSlab(slab: Slab*)
	{
		dst: Slab**;
		final switch (slab.extent.kind) with (Extent.Kind) {
		case None: dst = &freeSlabs[slab.order]; break;
		case Ptr: dst = &freePtrSlabs[slab.order]; break;
		case Fin: dst = &freeFinSlabs[slab.order]; break;
		case PtrFin: dst = &freePtrFinSlabs[slab.order]; break;
		}

		current := *dst;
		while (current !is null) {
			// Remove the slab from the list if found.
			if (current is slab) {
				*dst = current.next;
				break;
			}
			dst = &current.next;
			current = *dst;
		}

		// Push the slab to the used list.
		slab.next = usedSlabs;
		usedSlabs = slab;
	}

	fn allocLarge(n: size_t, hasFinalizer: bool, hasPointer: bool) void*
	{
		// Do this first so we don't accidentally free the memory
		// we just allocated. Also allocMemoryFromOS might grab
		// a just recently freed memory region.
		maybeTriggerCollection();

		// Grab memory from the OS.
		memorysz := roundUpToPageSize(n);
		if (memorysz < n) {
			/* Value has wrapped around; user has probably passed a
			 * small negative value to an allocate function.
			 */
			vrt_gc_print_stats();
			panicFailedToAlloc(n);
		}
		memory := mManager.allocMemoryFromOS(memorysz);
		if (memory is null) {
			collect();
			memory = mManager.allocMemoryFromOS(memorysz);
			if (memory is null) {
				vrt_gc_print_stats();
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

	fn allocSlab(order: u8, hasFinalizer: bool, hasPointer: bool) Slab*
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
		slab.setup(order:order, memory:memory, finalizer:hasFinalizer, pointer:hasPointer, internal:false);

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
			s := cast(Slab*)e;

			foreach (i; 0 .. Slab.MaxSlots) {
				slot := cast(u32)i;
				if (!s.isMarked(slot) && !s.isFree(slot)) {
					s.free(slot);
				}
			}
		} else {
			l := cast(Large*)e;
			if (l.isMarked) {
				return;
			}

			hl := removes.add();
			hl.extent = e;
		}
	}

	fn runAllFinalizers(n: Node*)
	{
		e := cast(Extent*)n;
		if (!e.hasFinalizer) {
			return;
		}

		if (e.isSlab) {
			s := cast(Slab*)e;

			foreach (i; 0 .. Slab.MaxSlots) {
				slot := cast(u32)i;
				if (s.isFree(slot)) {
					continue;
				}

				obj := cast(Object)s.slotToPointer(slot);
				gcAssert(obj !is null);
				obj.__dtor();
			}
		} else {
			l := cast(Large*)e;

			obj := cast(Object)l.extent.ptr;
			gcAssert(obj !is null);
			obj.__dtor();
		}
	}

	///a Does n contain an empty Slab?
	fn emptySlab(n: Node*) bool
	{
		s := cast(Slab*)n;
		return s.freeSlots > 0;
	}
}
