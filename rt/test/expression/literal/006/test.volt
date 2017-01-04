//T default:no
//T macro:expect-failure
//T check:expected static array literal of length 2
module test;

fn main() i32
{
	x: i32[2];
	x = [1, 2, 3];
	return x[0] + x[1];
}

