// Copyright 2016-2017, Jakob Bornecrantz.  All rights reserved.
// Copyright 2010-2012, Jonathan M Davis.  All rights reserved.
// Copyright 2010-2012, Kato Shoichi.  All rights reserved.
// See copyright notice in src/watt/license.volt (BOOST ver. 1.0).
module vrt.os.monotonic;

version (Windows || OSX || Posix):


extern(C) fn vrt_monotonic_ticks_per_second() i64
{
	return ticksPerSecond;
}

extern(C) fn vrt_monotonic_ticks_at_init() i64
{
	return ticksAtInit;
}

extern(C) fn vrt_monotonic_init()
{
	version (Windows) {
		ticksPerSecond = windowsTicksPerSecond();
	} else version (OSX) {
		ticksPerSecond = machTicksPerSecond();
	} else version (Posix) {
		ticksPerSecond = posixTicksPerSecond(CLOCK_MONOTONIC);
	}
	ticksAtInit = vrt_monotonic_ticks();
}

extern(C) fn vrt_monotonic_ticks() i64
{
	version (Windows) {
		return windowsTicks();
	} else version (OSX) {
		return machTicks();
	} else version (Posix) {
		return posixTicks(CLOCK_MONOTONIC);
	}
}

global ticksAtInit: i64;
global ticksPerSecond: i64;

version (Windows) {

	import core.c.stdlib: exit;
	import core.c.windows.windows : QueryPerformanceFrequency, QueryPerformanceCounter;

	fn windowsTicksPerSecond() i64
	{
		ticks: i64;
		if (QueryPerformanceFrequency(&ticks) == 0) {
			exit(-1);
		}
		return ticks;
	}

	fn windowsTicks() i64
	{
		ticks: i64;
		if (QueryPerformanceCounter(&ticks) == 0) {
			exit(-1);
		}
		return ticks;
	}

} else version (OSX) {

	import core.c.stdlib: exit;

	extern(C) {
		struct mach_timebase_info_data_t
		{
			numer: u32;
			denom: u32;
		}

		alias mach_timebase_info_t = mach_timebase_info_data_t*;

		fn mach_timebase_info(mach_timebase_info_t) i32;

		fn mach_absolute_time() u64;
	}

	/*
	 * Grabbed verbatim from druntume, good thing its BOOST v1.0 as well.
	 */
	fn machTicksPerSecond() i64
	{
		info: mach_timebase_info_data_t;
		if(mach_timebase_info(&info) != 0) {
			exit(-1);
		}

		scaledDenom: i64 = 1_000_000_000L * info.denom;
		if (scaledDenom % info.numer != 0) {
			exit(-1);
		}

		return scaledDenom / info.numer;
	}

	fn machTicks() i64
	{
		return cast(i64)mach_absolute_time();
	}

} else version (Posix) {

	import core.c.stdlib: exit;
	import core.c.posix.time;

	fn posixTicksPerSecond(clock: i32) i64
	{
		ts: timespec;
		if (clock_getres(clock, &ts) !=  0) {
			exit(-1);
		}
		return ts.tv_nsec >= 1000 ?
			1_000_000_000L :
			1_000_000_000L / ts.tv_nsec;
	}

	fn posixTicks(clock: i32) i64
	{
		ts: timespec;
		if (clock_gettime(clock, &ts) != 0) {
			exit(-1);
		}
		return convClockFreq(
			ts.tv_sec * 1_000_000_000L + ts.tv_nsec,
			1_000_000_000L, ticksPerSecond);
	}

}

/*
 * Grabbed from druntime, good thing its BOOST v1.0 as well.
 */
@safe pure nothrow
fn convClockFreq(ticks: i64, srcTicksPerSecond: i64, dstTicksPerSecond: i64) i64
{
	// This would be more straightforward with floating point arithmetic,
	// but we avoid it here in order to avoid the rounding errors that that
	// introduces. Also, by splitting out the units in this way, we're able
	// to deal with much larger values before running into problems with
	// integer overflow.
	return ticks / srcTicksPerSecond * dstTicksPerSecond +
		ticks % srcTicksPerSecond * dstTicksPerSecond / srcTicksPerSecond;
}
