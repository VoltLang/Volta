module test;

fn main() i32
{
	x: i32 = 3;
	fn func() i32 { return 12 + x; }
	return func() - 15;
}
