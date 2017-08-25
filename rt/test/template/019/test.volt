//T macro:expect-failure
//T check:reserved
module test;


struct Definition!(T)
{
	// This shadows the T, it is an error.
	T: u32;
}

struct Instance = mixin Definition!string;

fn main() i32
{
	return 0;
}
