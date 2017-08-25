//T macro:expect-failure
//T check:not marked with 'override'
// Test that abstract implementations must be marked as override.
module test;


abstract class Parent
{
	abstract int method();
}

class Child : Parent
{
	fn method() i32 { return 3; }
}

fn main() i32
{
	return 3;
}
