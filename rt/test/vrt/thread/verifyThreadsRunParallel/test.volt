module main;

import core.rt.thread;

global counter: u64;
global running := true;

fn main() i32
{
	thread1 := vrt_thread_start_fn(threadOne);
	while (counter != 0) {
	}
	running = false;
	vrt_thread_join(thread1);
	return 0;
}

fn threadOne()
{
	while (running) {
		counter++;
	}
}
