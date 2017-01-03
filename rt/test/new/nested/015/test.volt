module test;


// Function with nested function recursion.
fn main() i32
{
	fn func(val: i32) i32
	{
		// If case just to stop endless recursion, not needed.
		if (val == 42) {
			// Calling this function changes val.
			func(6);
			return val;
		} else {
			return 0;
		}
	}

	return func(42) - 42;
}
