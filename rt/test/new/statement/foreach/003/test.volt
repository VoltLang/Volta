module test;


fn main() i32
{
	ints: i32[] = [2, 1, 0];

	c: i32;
	foreach_reverse (v; ints) {
		if (v != c++) {
			return 1;
		}
	}
	if (c != 3) {
		return 2;
	}

	foreach_reverse (i, v; ints) {
		if (cast(i32)i != --c) {
			return 3;
		}
	}
	if (c != 0) {
		return 4;
	}

	return 0;
}
