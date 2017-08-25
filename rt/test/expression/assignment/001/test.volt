//T macro:expect-failure
//T check:cannot modify
// Ensure that const values can't be assigned to.
module test;

fn main() i32
{
	i: const(i32);
	i = 42;
	return i;
}
