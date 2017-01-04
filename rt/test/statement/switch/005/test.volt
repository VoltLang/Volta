// Multiple cases on one case statement.
module test;

fn main() i32
{
	switch (2) {
	case 1, 2, 3:
		return 0;
	default:
		return 9;
	}
}
