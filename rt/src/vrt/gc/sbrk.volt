// Copyright 2016-2017, Bernard Helyer.
// Copyright 2016-2017, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module vrt.gc.sbrk;

version (Linux || OSX):

import core.c.stdint : intptr_t;

import core.typeinfo : TypeInfo;
import core.rt.gc : Stats;
import core.rt.misc : vrt_panic;
import core.compiler.llvm;
import core.object : Object;

import vrt.gc.design;
import vrt.gc.util : gcAssert;


extern(C) fn sbrk(increment: intptr_t) void*;

global inst: SBrk;

struct SBrk
{
public:
	enum Max = 0x200000; // 2 MB
	enum Own = 0x010000; // 64 K
	cur: void*;
	left: size_t;
	used: size_t;


private:
	mStats: Stats.Num;


public:
	fn setup()
	{
		cur = sbrk(Max);
	}

	fn shutdown()
	{

	}

	fn collect()
	{

	}

	fn getStats(out stats: Stats)
	{
		stats.num = mStats;
	}

	fn totalSize() size_t
	{
		return cast(size_t)mStats.allocBytes;
	}

	fn allocEntry(typeinfo: TypeInfo, count: size_t) void*
	{
		size: size_t;
		memory: void*;
		registerFinalizer := false;

		if (count == 0) {
			mStats.zeroAllocs++;
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

		// Mirror Arena logic.
		if (size < MinAllocSize) {
			size = MinAllocSize;
		}

		// Statistics
		mStats.allocs++;
		mStats.allocBytes += size;
		if (count == cast(size_t) -1) {
			mStats.classAllocs++;
			mStats.classBytes += size;
		} else if (count > 0) {
			mStats.arrayAllocs++;
			mStats.arrayBytes += size;
		}

		memory = alloc(size);
		gcAssert(memory !is null);

		if (count == cast(size_t) -1) {
			__llvm_memcpy(memory, typeinfo.classInit, typeinfo.classSize, 0, false);
		} else {
			__llvm_memset(memory, 0, size, 0, false);
		}

		return memory;
	}

	fn alloc(size: size_t) void*
	{
		if (size <= left) {
			ret := cur + used;
			used += size;
			left -= size;
			return ret;
		} else if (size >= Own) {
			return sbrk(cast(intptr_t)size);
		} else {
			cur = sbrk(Max);
			left = Max - size;
			used = size;
			return cur;
		}
	}
}
