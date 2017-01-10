//T default:no
//T macro:expect-failure
//T check:access
module test;

public fn sum(a: i32) i32
{
	return a;
}

private fn sum(a: i32, b:i32) i32
{
	return a + b;
}

fn main() i32
{
	return sum(1) + sum(2, 3) - 6;
}

