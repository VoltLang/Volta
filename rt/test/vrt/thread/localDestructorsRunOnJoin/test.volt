module main;

import core.rt.thread;

local this()
{
	localVar += 2;
}

local ~this()
{
	localVar -= 2;
}

global ~this()
{
	// The threads terminating should not run this.
	localVar -= 100;
}

global localVar: i32;

fn main() i32
{
	t1 := vrt_thread_start_fn(threadOne);
	vrt_thread_join(t1);
	t2 := vrt_thread_start_fn(threadOne);
	vrt_thread_join(t2);
	t3 := vrt_thread_start_fn(threadOne);
	vrt_thread_join(t3);

	return localVar - 2;  // The main thread is still running, so localVar is 2, *not* 0!
}

fn threadOne()
{
}
