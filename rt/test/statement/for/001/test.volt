module test;


fn main() i32
{
	// So that the value can escape the loop.
	ret: i32;

	for (i: i32; i <= 2; i++) {
		f: i32;

		// This should be 2 since f should be reset.
		// But it isn't reset so it gets the wrong value.
		f += i;

		// Escape the loop.
		ret = f;
	}

	return ret - 2;
}
