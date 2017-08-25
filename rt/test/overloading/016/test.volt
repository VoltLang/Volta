//T macro:expect-failure
//T check:no matching function to override
// Test that top level functions cannot be marked override.
module test;


override fn x() i32
{
	return 42;
}

fn main() i32
{
	return x();
}
