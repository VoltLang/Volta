module test;

fn main() i32
{
	ret: i32 = 4;

	switch (3) {
	case 2:
		return 2;
	case 3: // This doesn't fall through as expected.
	default:
		ret = 0;
	}
	return ret;
}
