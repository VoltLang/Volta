module main;

import core.rt.thread;

global counter: u64;

fn main() i32
{
	thread1 := vrt_thread_start_fn(threadOne);
	while (counter != 0) {
	}
	return 0;
}

fn threadOne()
{
	while (true) {
		counter++;
	}
}
