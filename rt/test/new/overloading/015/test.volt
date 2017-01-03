// Overriding with structs.
module test;


struct S
{
	fn add(a: i32, b: i32) i32
	{
		return a + b;
	}

	fn add(a: f32, b: f32) f32
	{
		return a;
	}
}

fn main() i32
{
	s: S;
	return s.add(32, 2) - 34;
}
