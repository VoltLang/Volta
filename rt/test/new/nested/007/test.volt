module test;

fn main() i32
{
	x: i32;
	x = 2;
	fn func() i32
	{
		y: i32;
		if (x == 2) {
			y = 4;
		}
		return x * y;
	}
	return func() - 8;
}
