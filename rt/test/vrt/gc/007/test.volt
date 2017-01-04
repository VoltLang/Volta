module test;

import vrt.ext.stdc;
import vrt.gc.entry;

class Greeter
{
}

fn main() i32
{
	greeter := new Greeter();
	vrt_gc_collect();
	return 0;
}

