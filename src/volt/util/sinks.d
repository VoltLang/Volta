// Copyright © 2015-2016, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/licence.d (BOOST ver 1.0).
module volt.util.sinks;

import ir = volt.ir.ir;


/*
 * These creates arrays of types,
 * with minimal allocations. Declare on the stack.
 */

struct SinkStruct(T)
{
public:
	//! The one true sink definition.
	alias Sink = void delegate(SinkArg);

	//! The argument to the one true sink.
	alias SinkArg = scope T[];

	enum size_t MinSize = 16;
	enum size_t MaxSize = 2048;

	@property size_t length()
	{
		return mLength;
	}

private:
	T[32] mStore;
	T[] mArr;
	size_t mLength;


public:
	void sink(T type)
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

		auto n = new T[](allocSize);
		n[0 .. mLength] = mArr[0 .. mLength];
		n[mLength++] = type;
		mArr = n;
	}

	void append(T[] arr)
	{
		foreach (e; arr) {
			sink(e);
		}
	}

	void append(SinkStruct s)
	{
		void func(SinkArg sa)
		{
			foreach (e; sa) {
				sink(e);
			}
		}

		version (Volt) {
			s.toSink(func);
		} else {
			s.toSink(&func);
		}
	}

	void popLast()
	{
		if (mLength > 0) {
			mLength--;
		}
	}

	T getLast()
	{
		return mArr[mLength - 1];
	}

	T get(size_t i)
	{
		return mArr[i];
	}

	void set(size_t i, T n)
	{
		mArr[i] = n;
	}

	void setLast(T i)
	{
		mArr[mLength - 1] = i;
	}

	/*!
	 * Safely get the backing storage from the sink without copying.
	 */
	void toSink(Sink sink)
	{
		return sink(mArr[0 .. mLength]);
	}

	/*!
	 * Use this as sparingly as possible. Use toSink where possible.
	 */
	T[] toArray()
	{
		auto _out = new T[](mLength);
		_out[] = mArr[0 .. mLength];
		return _out;
	}

	/*!
	 * Unsafely get a reference to the array.
	 */
	T[] borrowUnsafe()
	{
		return mArr[0 .. mLength];
	}

	void reset()
	{
		mLength = 0;
	}
}

alias IntSink = SinkStruct!int;
alias FunctionSink = SinkStruct!(ir.Function);
alias FunctionArraySink = SinkStruct!(ir.Function[]);
alias VariableSink = SinkStruct!(ir.Variable);
