//T macro:expect-failure
//T check:cannot access variable 'f'
module test;


fn main() i32
{
	f: i32 = 42;

	static fn func()
	{
		// Static functions should not be able
		// to access function variables (or nested).
		f = 5;
	}
	func();

	return f;
}
