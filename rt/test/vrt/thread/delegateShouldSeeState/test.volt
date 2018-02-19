module main;

import core.rt.thread;

class SomeClass
{
	data: i32;

	fn addOne()
	{
		data += 1;
	}
}

fn main() i32
{
	sc1 := new SomeClass();
	sc1.data = 12;
	sc2 := new SomeClass();

	t1 := vrt_thread_start_dg(sc1.addOne);

	vrt_thread_join(t1);

	return (sc1.data - 13) + sc2.data;
}
