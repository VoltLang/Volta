//T macro:warnings
//T check:assign in condition
module test;

fn main() i32
{
	x: i32;
	if (x = 0) {
		return 1;
	}
	while (x = 0) {
	}
	do {
	} while (x = 0);
	for (; x = 0;) {
	}
	return 0;
}
