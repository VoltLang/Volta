// Array allocation and copy with new.
module test;

fn main() i32
{
	a: i32[] = new i32[](3);
	b: i32[] = [1, 2, 3];
	c: i32[] = new i32[](a, b);

	if (c == [0, 0, 0, 1, 2, 3]) {
		return 0;
	}

	return 1;
}
