// Ensures that test 2 isn't a fluke.
module test;


fn main() i32
{
	if (true) {
		x: i32 = 0;
		return x;
	} else {
		x: i32 = 4;
		return x;
	}
}

