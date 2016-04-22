// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.perf;

import watt.io.std : writefln;
import watt.io.streams : OutputFileStream;

import mt = watt.io.monotonic;


/**
 * Very simple perfing code, just gets timing info.
 *
 * Yes these times are not super accurate and will drift a lot
 * over time. So don't be using these for missile guidence.
 */
struct Perf
{
	int pos;
	long[] times;
	string[] names;

	enum Mark {
		SETUP,
		PARSING,
		PHASE1,
		PHASE2,
		PHASE3,
		BACKEND,
		BITCODE,
		ASSEMBLE,
		LINK,
		EXIT,
		DONE,
	}

	enum string[] markNames = [
		"setup",
		"parsing",
		"phase1",
		"phase2",
		"phase3",
		"backend",
		"bitcode-link",
		"assemble",
		"native-link",
		"exit",
		"done",
	];

	/**
	 * Place a mark in time, allows to skip phases.
	 */
	void mark(Mark mark)
	{
		assert(mark <= Mark.DONE);

		auto t = mt.ticks();
		while (mark >= pos) {
			times ~= t;
			names ~= markNames[pos];
			pos++;
		}
	}

	void print(string file, string name)
	{
		auto f = new OutputFileStream(file);

		f.writef("name,total,");
		for (size_t i = 1; i < times.length; i++) {
			f.writef("%s,", names[i-1]);
		}
		f.writef("\n");

		f.writef("%s,", name);
		void doWrite(long t) {
			t = mt.convClockFreq(t, mt.ticksPerSecond, 1_000_000);
			f.writef("%s,", t);
		}
		doWrite(times[$-1] - times[0]);
		for (size_t i = 1; i < times.length; i++) {
			doWrite(times[i] - times[i-1]);
		}
		f.writef("\n");
		f.flush();
		f.close();
	}
}

static Perf perf;
