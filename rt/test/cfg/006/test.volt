//T macro:expect-failure
//T check:statement not reached
module test;

// Accepts-bad.
fn f02(b: bool)
{
	if (b) {
		return;
	} else {
		return;
	}

	// Should not accept.
	assert(false);
}

fn main() i32
{
	f02(false);
	return 0;
}
