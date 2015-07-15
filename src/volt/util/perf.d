module volt.util.perf;

private import core.time : MonoTime;
private import std.stdio : writefln;

/**
 * Very simple perfing code, just gets timing info.
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

		for (size_t i = 1; i < times.length; i++) {
			auto t = times[i].ticks() - times[i-1].ticks();
			auto tps = MonoTime.ticksPerSecond() / 100000;
			t = t / tps;
			writefln("%*s: %6s.%02s msec",
			         max + 1, names[i-1],
			         t / 100, t % 100);
		}
	}
}

Perf perf;
