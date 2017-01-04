module test;

fn main() i32
{
	x: i32[2];
	a: i32 = 1;
	b: i32 = 2;
	x = [a, b];
	return x[0] + x[1] - 3;
}

