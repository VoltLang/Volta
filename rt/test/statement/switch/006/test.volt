// Case range switch statement.
module test;

fn main() i32
{
	switch (3) {
	case 1: .. case 3:
		return 0;
	default:
		return 9;
	}
}
