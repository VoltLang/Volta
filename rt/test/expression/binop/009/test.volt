//T macro:expect-failure
module test;

fn main() i32
{
	a: i32 = 2;
	b: i32 = 3;
	a * b;
	return 0;
}

