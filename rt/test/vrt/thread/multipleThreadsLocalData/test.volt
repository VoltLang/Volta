//T requires:!x86
module main;

import core.rt.thread;

local counter: i32;
global results: i32[3];

fn main() i32
{
	thread1 := vrt_thread_start_fn(threadOne);
	thread2 := vrt_thread_start_fn(threadTwo);
	vrt_thread_join(thread1);
	vrt_thread_join(thread2);
	results[0] = counter;
	if (results[0] != 0) {
		return 1;
	}
	if (results[1] != 1) {
		return 2;
	}
	if (results[2] != 2) {
		return 3;
	}
	return 0;
}

fn threadOne()
{
	counter = 1;
	results[1] = counter;
}

fn threadTwo()
{
	counter = 2;
	results[2] = counter;
}
