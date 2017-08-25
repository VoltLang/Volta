//T macro:expect-failure
module test;


fn main() i32
{
	x: i32;
	if (true) {
		x: i32 = 3;
		return x;
	} else {
		x: i32 = 4;
		return x;
	}
}

