//T macro:expect-failure
//T check:expected
module test;

fn add(a: i32, b: i32) i32
{
	return a + b;
}

fn main() i32
{
	return add(1, 2,);
}
