//T macro:expect-failure
//T check:statement not reached
module test;

// Maybe a variant of f02
fn f03(i: i32) i32
{
	switch (i) {
	case 12:
		if (i == 13) {
			goto case 187;
		} else {
			goto default;
		}
		return 6;  // This should error.
	case 187:
		return 5;
	default:
		break;
	}
	return 0;
}

fn main() i32
{
	f03(12);
	return 0;
}
