module main;

import core.rt.thread;

global this()
{
	x += 32;
}

global x: i32;
global y: i32;

fn main() i32
{
	t := vrt_thread_start_fn(theThread);
	vrt_thread_join(t);
	if (vrt_thread_error(t)) {
		return 1;
	}
	return y - 32;
}

fn theThread()
{
	y = x;
}
