//T macro:expect-failure
//T check:cannot modify
// Test transitive dereferencing.
module test;


fn main() i32
{
	i: i32 = 42;
	const p = &i;
	*p = 42;
	return i;
}
