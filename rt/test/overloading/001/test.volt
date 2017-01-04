// Most basic overloading test -- number of arguments.
module test;


fn add(a: i32, b: i32) i32
{
	return a + b;
}

fn add(a: i32, b: i32, c: i32) i32
{
	return a + b + c;
}

fn main() i32
{
	return add(add(10, 10), 20, 2) - 42;
}
