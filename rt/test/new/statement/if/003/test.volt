module test;

fn main() i32
{
	b := false;
	if (!false) {
		return 0;
	}
	if (!b) {
		return 2;
	}
	return 1;
}
