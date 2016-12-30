//T default:no
//T macro:expect-failure
module test;

fn main() i32
{
	foo: bool;
	// Should not implicitly convert to a bool.
	foo = 0;
	return 0;
}

