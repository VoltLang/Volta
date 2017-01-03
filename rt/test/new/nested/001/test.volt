module test;

fn main() i32
{
	x: i32;
	x = 2;
	fn func(y: i32) i32
	{ 
		return y * x;
	}
	return func(3) - 6;
}
