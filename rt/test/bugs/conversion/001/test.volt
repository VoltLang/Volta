//T macro:expect-failure
// scope and '&' causes pointers to be accepted when it shouldn't.
module test;


fn func(t: scope char*)
{
}

fn main() i32
{
	argz: i32;
	// Removing scope above also fixes the issue.
	func(&argz); // Clearly the wrong type here.

	// int* argz;
	// func(argz); // Fails as expected.
	return 0;
}
