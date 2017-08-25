//T macro:expect-failure
//T check:no member
module test;


struct Definition!(T)
{
	a: T;
}

struct Instance = mixin Definition!string;

fn main() i32
{
	// Should not be able to access the T symbol.
	a: Instance.T;
	return 0;
}
