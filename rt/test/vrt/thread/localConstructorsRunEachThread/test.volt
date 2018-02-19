module main;

import core.rt.thread;

global this()
{
	globalVar += 2;
}

local this()
{
	localVar += 2;
}

global localVar: i32;
global globalVar: i32;

fn main() i32
{
	t1 := vrt_thread_start_fn(threadOne);
	t2 := vrt_thread_start_fn(threadOne);
	t3 := vrt_thread_start_fn(threadOne);

	vrt_thread_join(t1);
	vrt_thread_join(t2);
	vrt_thread_join(t3);

	return (globalVar - 2) + (localVar - 8);
}

fn threadOne()
{
}
