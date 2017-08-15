module test;

// Maybe a variant of f02
fn f03(b: bool) i32
{
	if (b) {
		if (!b) {
			return 0;
		}
		return 0;
	} else {
		return 0;
	}
}

fn main() i32
{
	f03(false);
	return 0;
}
