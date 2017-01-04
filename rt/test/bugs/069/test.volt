module test;

fn addTogether(a: i32, b: i32) i32
{
	return a + b;
}

fn main() i32
{
	x: i32 = 41;
	fn addTogether(a: i32) i32
	{
		return .addTogether(a, x);
	}
	return addTogether(1) - 42;
}

