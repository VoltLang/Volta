//T macro:expect-failure
//T check:calls to @label functions
module test;

@label fn add(a: i32, b: i32) i32
{
	return a + b;
}

fn main() i32
{
	return add(16, 16);
}
