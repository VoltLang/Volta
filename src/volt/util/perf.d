// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.perf;

version (Volt) {
	import core.typeinfo;
	import core.rt.gc;
}

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

	Counter counter;

	Accumulator stack;
	Accumulator accum;

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
		NUM_MARKS, // Ensure that this is last.
	}

	void init()
	{
		auto t = mt.ticks();
		times = new long[](cast(size_t)Mark.NUM_MARKS);
		times[pos++] = t;

		stack = new Accumulator("other");
		stack.then = t;

		version (none) {
			new GCAccumulator();
		} else {
			new Accumulator("GC");
		}
	}

	void close()
	{
		assert(stack.below is null);

		auto t = mt.ticks();

		stack.accum += t - stack.then;
		while (Mark.DONE >= pos) {
			times[pos++] = t;
		}
	}

	/**
	 * Place a mark in time, allows to skip phases.
	 */
	void mark(Mark mark)
	{
		assert(mark > Mark.SETUP);
		assert(mark < Mark.DONE);

		auto t = mt.ticks();
		while (mark >= pos) {
			times[pos++] = t;
		}
	}

	void print(string file, string name)
	{
		auto f = new OutputFileStream(file);
		auto total = times[$-1] - times[0];

		void doWrite(long t) {
			t = mt.convClockFreq(t, mt.ticksPerSecond, 1_000_000);
			f.writef("%s,", t);
		}

		// First line, names of marks.
		f.writef("--- Phases\n");
		f.writef("name,");
		for (size_t i = 1; i < times.length; i++) {
			f.writef("%s,", markNames[i-1]);
		}
		f.writef("total,\n%s,", name);
		for (size_t i = 1; i < times.length; i++) {
			doWrite(times[i] - times[i-1]);
		}
		doWrite(total); f.writef("\n\n");


		f.writef("--- Accumulators\n");
		f.writef("name,");
		for (auto a = accum; a !is null; a = a.next) {
			f.writef("%s,", a.name);
		}
		f.writef("\n%s,", name);
		for (auto a = accum; a !is null; a = a.next) {
			doWrite(a.accum);
		}
		f.writef("\n\n");


		f.writef("--- Counters\n");
		f.writef("name,GC-numAllocs,GC-numAllocBytes,GC-numArrayAllocs,GC-numArrayBytes,GC-numClassAllocs,GC-numClassBytes,GC-numZeroAllocs");
		for (auto c = counter; c !is null; c = c.next) {
			f.writef("%s,", c.name);
		}
		f.writef("\n%s,", name);
		version (Volt) {
			Stats stats;
			vrt_gc_get_stats(stats);
			f.writef("%s,%s,%s,%s,%s,%s,%s",
			         stats.numAllocs,      stats.numAllocBytes,
			         stats.numArrayAllocs, stats.numArrayBytes,
			         stats.numClassAllocs, stats.numClassBytes,
			         stats.numZeroAllocs);
		} else {
			f.writef("0,0,0,0,0,0,0,");
		}
		for (auto c = counter; c !is null; c = c.next) {
			f.writef("%s,", c.count);
		}
		f.writef("\n\n");

		f.flush();
		f.close();
	}

private:
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
}

class Accumulator
{
public:
	long accum;
	long then;

	Accumulator below; // Accumulator below this.
	Accumulator next;
	string name;


public:
	this(string name)
	{
		this.name = name;
		this.next = perf.accum;
		perf.accum = this;
	}

	void start()
	{
		auto now = mt.ticks();

		below = perf.stack;
		perf.stack = this;

		below.accum += now - below.then;
		this.then = now;
	}

	void stop()
	{
		auto now = mt.ticks();
		accum += now - this.then;

		below.then = now;
		perf.stack = below;
		below = null;
	}
}

class Counter
{
public:
	string name;
	ulong count;
	Counter next;


public:
	this(string name)
	{
		this.name = name;
		assert(perf.counter is null);
		this.next = perf.counter;
		perf.counter = this;
	}
}

version (Volt) class GCAccumulator : Accumulator
{
	AllocDg mAllocDg;

	this()
	{
		super("GC");
		mAllocDg = allocDg;
		allocDg = alloc;
	}

	void* alloc(TypeInfo ti, size_t c)
	{
		start();
		auto ret = allocDg(ti, c);
		stop();
		return ret;
	}
}

static Perf perf;
