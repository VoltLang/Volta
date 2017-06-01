// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/watt/licence.volt (BOOST ver 1.0).
module watt.text.sink;


//! The one true sink definition.
alias Sink = scope void delegate(scope SinkArg);

//! The argument to the one true sink.
alias SinkArg = scope const(char)[];

//! A sink to create long strings.
struct StringSink
{
private:
	char[] mArr;
	size_t mLength;

	enum size_t minSize = 16;
	enum size_t maxSize = 2048;

public:
	void sink(scope SinkArg str)
	{
		auto newSize = str.length + mLength;
		if (newSize <= mArr.length) {
			mArr[mLength .. newSize] = str[];
			mLength = newSize;
			return;
		}

		auto allocSize = mArr.length;
		while (allocSize < newSize) {
			if (allocSize < minSize) {
				allocSize = minSize;
			} else if (allocSize >= maxSize) {
				allocSize += maxSize;
			} else {
				allocSize = allocSize * 2;
			}
		}

		auto n = new char[](newSize + 256);
		n[0 .. mLength] = mArr[0 .. mLength];
		n[mLength .. newSize] = str[];
		mLength = newSize;
		mArr = n;
	}

	version (D_Version2) Sink sink()
	{
		return &sink;
	}

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
		mArr = [];
		mLength = 0;
	}
}
