module test;

fn add(a: i32, b: i32, c: i32 = 3) i32
{
	return a + b + c;
}

fn main() i32
{
	return add(a:16, b:16) - 35;
}
