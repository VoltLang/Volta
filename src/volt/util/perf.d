// Copyright © 2015, Jakob Bornecrantz.  All rights reserved.
// See copyright notice in src/volt/license.d (BOOST ver. 1.0).
module volt.util.perf;


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

	void print()
	{
		size_t max;
		foreach(s; names) {
			max = s.length > max ? s.length : max;
		}

		writefln("%*s            part          total", max + 1, "");
		long s;
		for (size_t i = 1; i < times.length; i++) {
			auto t = times[i].ticks() - times[i-1].ticks();
			auto tps = MonoTime.ticksPerSecond() / 100000;
			t = t / tps;
			s += t;
			writefln("%*s: %6s.%02s msec %6s.%02s msec",
			         max + 1, names[i-1],
			         t / 100, t % 100,
			         s / 100, s % 100);
		}
	}
}

Perf perf;
