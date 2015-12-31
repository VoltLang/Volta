// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.perf;


version (Volt) {
	struct Perf
	{
		void tag(string) {}
		void print(string name) {}
	}

	static Perf perf;
}

version (D_Version2):

import watt.io.std : writefln;
private import core.time : MonoTime;

/**
 * Very simple perfing code, just gets timing info.
 *
 * Yes these times are not super accurate and will drift a lot
 * over time. So don't be using these for missile guidence.
 */
struct Perf
{
	MonoTime[] times;
	string[] names;

	void tag(string tag)
	{
		times ~= MonoTime();
		names ~= tag;
		times[$-1] = MonoTime.currTime;
	}

	void print(string name)
	{
		import std.stdio : File;
		auto f = File("perf.cvs", "w");

		f.write("name, total, ");
		for (size_t i = 1; i < times.length; i++) {
			f.writef("%s,", names[i-1]);
		}
		f.writeln();

		f.writef("%s,", name);
		ulong tps = MonoTime.ticksPerSecond() / 100000;
		void write(ulong t) {
			t = t / tps;
			f.writef("%s.%02s,", t / 100, t % 100);
		}
		write(times[$-1].ticks() - times[0].ticks());
		for (size_t i = 1; i < times.length; i++) {
			write(times[i].ticks() - times[i-1].ticks());
		}
		f.writeln();
	}
}

Perf perf;
