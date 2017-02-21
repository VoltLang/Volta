// Copyright © 2016-2017, Jakob Bornecrantz.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module vrt.gc.hit;

import core.compiler.llvm;

import vrt.gc.extent;
import vrt.gc.slab;
import vrt.gc.util;
import vrt.gc.mman;


struct HitEntry
{
	extent: Extent*;
	ptr: void*;
}

struct HitStack
{
private:
	mList: HitEntry*;
	mLength: size_t;
	mMax: size_t;
	mEntriesPerPage: size_t;

public:
	fn init()
	{
		mEntriesPerPage = getPageSize() / typeid(HitEntry).size;
	}

	fn add() HitEntry*
	{
		size := typeid(HitEntry).size;

		if (mLength + 1 > mMax) {
			oldMax := mMax;
			mMax += mEntriesPerPage;
			n := size * mMax;
			newList := cast(HitEntry*)pages_map(null, n);
			if (mList !is null) {
				newList[0 .. oldMax] = mList[0 .. oldMax];
				pages_unmap(cast(void*)mList, oldMax);
			}
			mList = newList;
		}
		ret := &mList[mLength++];
		__llvm_memset(cast(void*)ret, 0, size, 0, false);
		return ret;
	}

	fn top() HitEntry*
	{
		if (mLength > 0) {
			return &mList[mLength-1];
		} else {
			return null;
		}
	}

	fn pop()
	{
		if (mLength > 0) {
			--mLength;
		}
	}

	fn reset()
	{
		mLength = 0;
	}

	fn free()
	{
		reset();

		if (mList !is null) {
			pages_unmap(cast(void*)mList, mMax);
		}
		mList = null;
	}
}
