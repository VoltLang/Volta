// Copyright 2015, Jakob Bornecrantz.
// SPDX-License-Identifier: BSL-1.0
module watt.text.sink;


//! The one true sink definition.
alias Sink = void delegate(scope SinkArg) scope;

//! The argument to the one true sink.
alias SinkArg = const(char)[];

//! A sink to create long strings.
struct StringSink
{
private:
	char[64] mStore;
	char[] mArr;
	size_t mLength;

	enum size_t MaxSize = 1024;

public:
	void sink(scope SinkArg str) scope
	{
		if (mArr.length == 0) {
			mArr = mStore;
		}

		auto newSize = str.length + mLength;
		if (newSize <= mArr.length) {
			mArr[mLength .. newSize] = str[];
			mLength = newSize;
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

		if (allocSize != mArr.length) {
			auto n = new char[](allocSize);
			n[0 .. mLength] = mArr[0 .. mLength];
			mArr = n;
		}

		mArr[mLength .. newSize] = str[];
		mLength = newSize;
	}

	version (D_Version2) mixin(`
	Sink sink() return
	{
		return &sink;
	}`);

	string toString()
	{
		version (Volt) {
			return new string(mArr[0 .. mLength]);
		} else {
			return mArr[0 .. mLength].idup;
		}
	}

	void reset()
	{
		mLength = 0;
	}
}
