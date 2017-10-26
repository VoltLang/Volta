//T macro:expect-failure
//T check:with the wrong tag
module test;

fn a(ref i: i32, seed: i32) i32
{
	return i + 1;
}

fn b(seed: i32, ref i: i32) i32
{
	return i + 2;
}

fn main() i32
{
	integer := 6;
	return a(ref integer, b(0, out integer));
}
