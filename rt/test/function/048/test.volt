//T macro:expect-failure
//T check:cannot modify
// Simple in param test.
module test;


fn foo(in foo: i32*)
{
	*foo = 42;
}

fn main() i32
{
	i: i32;
	foo(&i);
	return i - 42;
}
