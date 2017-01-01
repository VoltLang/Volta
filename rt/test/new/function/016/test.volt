module test;

fn main() i32
{
	x: i32 = 12;
	fn getX() i32
	{
		return x;
	}
	return getX() - 12;
}
