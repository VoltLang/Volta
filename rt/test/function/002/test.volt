//T macro:expect-failure
module test;

fn mittu(ref i: i32) i32
{
}

fn main() i32
{
	i: i32;
	mittu(i);
	return i;
}

