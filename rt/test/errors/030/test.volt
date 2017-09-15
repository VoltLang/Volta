//T macro:import
module test;

public import m1 : add;

fn add(a: i32, b: i32) i32
{
	return a + b;
}

fn main() i32
{
	return add(1, 2, 3) - add(3, 3);
}
