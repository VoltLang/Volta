module test;

fn addOne(out x: i32)
{
	// x is initialized to zero.
	x++;
}

fn main() i32
{
	x: i32 = 22;
	addOne(out x);
	return x - 1;
}

