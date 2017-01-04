//T default:no
//T macro:expect-failure
//T check:all arguments must be labelled
module test;

fn add(a: i32, b: i32) i32
{
	return a + b;
}

fn main() i32
{
	return add(a:16, 16);
}

