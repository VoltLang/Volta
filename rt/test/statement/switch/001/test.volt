// Basic switch test.
module test;

fn main() i32
{
	switch (2) {
	case 1:
		return 1;
	case 2:
		return 0;
	case 3:
		return 7;
	default:
		return 9;
	}
}
