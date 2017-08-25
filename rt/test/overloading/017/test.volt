//T macro:expect-failure
//T check:no matching function to override
// Test that non class members cannot be marked override.
module test;


struct S
{
	override fn x() i32
	{
		return 42;
	}
}

fn main() i32
{
	s: S;
	return s.x();
}
