//T default:no
//T macro:expect-failure
//T check:cannot implicitly convert
module test;

fn main() i32
{
	x: i32[2];
	x = ["dsds", "summer"];
	return x[0] + x[1];
}

