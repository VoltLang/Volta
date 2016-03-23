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
	long[] times;
	string[] names;

	void tag(string tag)
	{
		times ~= mt.ticks();
		names ~= tag;
	}

	void print(string name)
	{
		auto f = new OutputFileStream("perf.cvs");

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
