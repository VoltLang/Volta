//T default:no
//T macro:expect-failure
//T check:statement not reached
module test;

// Maybe a variant of f02
fn f03(b: bool)
{
	switch (b) {
	case true:
		if (b) {
			goto default;
		} else {
			return;
		}
	case false:
		goto case true;
	default:
		return;
	}

	assert(false);
}

fn main() i32
{
	f03(false);
	return 0;
}
