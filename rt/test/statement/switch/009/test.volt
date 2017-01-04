// Switch goto.
module test;

fn main() i32
{
	switch (3) {
	case 1:
		return 1;
	case 2:
		goto default;
	case 3:
		goto case 2;
	default:
		return 0;
	}
}
