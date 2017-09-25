module test;

fn main() i32
{
	y := [1, 2, 3];
	y = (i32[]).init;
	return cast(i32)y.length;
}
