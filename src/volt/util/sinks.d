// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/licence.d (BOOST ver 1.0).
module volt.util.sinks;

import ir = volt.ir.ir;


/*
 * These creates arrays of types,
 * with minimal allocations. Declare on the stack.
 */

struct IntSink
{
public:
	/// The one true sink definition.
	alias Sink = void delegate(SinkArg);

	/// The argument to the one true sink.
	alias SinkArg = scope int[];

	enum size_t MinSize = 16;
	enum size_t MaxSize = 2048;

private:
	int[32] mStore;
	int[] mArr;
	size_t mLength;


public:
	void sink(int type)
	{
		auto newSize = mLength + 1;
		if (mArr.length == 0) {
			mArr = mStore[0 .. $];
		}

		if (newSize <= mArr.length) {
			mArr[mLength++] = type;
			return;
		}

		auto allocSize = mArr.length;
		while (allocSize < newSize) {
			if (allocSize >= MaxSize) {
				allocSize += MaxSize;
			} else {
				allocSize = allocSize * 2;
			}
		}

		auto n = new int[](allocSize);
		n[0 .. mLength] = mArr[0 .. mLength];
		n[mLength++] = type;
		mArr = n;
	}

	void popLast()
	{
		mArr = mArr[0 .. mLength - 1];
		mLength--;
	}

	int getLast()
	{
		return mArr[mLength - 1];
	}

	void setLast(int i)
	{
		mArr[mLength - 1] = i;
	}

	/**
	 * Safely get the backing storage from the sink without copying.
	 */
	void toSink(Sink sink)
	{
		return sink(mArr[0 .. mLength]);
	}

	void reset()
	{
		mLength = 0;
	}
}
