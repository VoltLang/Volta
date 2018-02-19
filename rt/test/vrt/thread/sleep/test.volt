module main;

import core.rt.thread;
import core.rt.misc;

fn main() i32
{
	a := vrt_monotonic_ticks();
	vrt_sleep(100);
	b := vrt_monotonic_ticks();
	d := b - a;
	if (d < (vrt_monotonic_ticks_per_second() / 10)) {
		return 1;
	} else {
		return 0;
	}
}

