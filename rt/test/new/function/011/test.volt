module test;

fn add(a: i32, b: i32 = 2) i32
{
	return a + b;
}

fn main() i32
{
	return (add(12, 2) + add(12)) - 28;
}
