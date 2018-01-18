/*#D*/
// Copyright © 2018, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/licence.d (BOOST ver 1.0).
module volta.util.stack;

import ir = volta.ir;

/*!
 * Reasonably efficient stack implementation.
 *
 * Minimal allocation code stolen from Sink.
 */
struct Stack(T)
{
public:
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
	/*!
	 * Add a value to become the top of the stack.
	 */
	void push(T val)
	{
		auto newSize = mLength + 1;
		if (mArr.length == 0) {
			mArr = mStore[0 .. $];
		}

		if (newSize <= mArr.length) {
			mArr[mLength++] = val;
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
		n[mLength++] = val;
		mArr = n;
	}

	/*!
	 * Remove the top element of the stack and return it.
	 */
	T pop()
	{
		assert(mArr.length > 0);
		T val = mArr[mLength-1];
		mLength--;
		return val;
	}

	/*!
	 * Return the top element of the stack without removing it.
	 */
	T peek()
	{
		assert(mArr.length > 0);
		return mArr[mLength-1];
	}

	/*!
	 * Reset the stack to an empty state.
	 */
	void clear()
	{
		mArr = null;
		mLength = 0;
	}

	/*!
	 * Unsafely get a reference to the array.
	 */
	T[] borrowUnsafe()
	{
		return mArr[0 .. mLength];
	}
}

alias FunctionStack = Stack!(ir.Function);
alias ExpStack = Stack!(ir.Exp);
alias ClassStack = Stack!(ir.Class);
alias BinOpOpStack = Stack!(ir.BinOp.Op);
alias BoolStack = Stack!bool;
alias StringStack = Stack!string;