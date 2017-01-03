// Ensure that overload erroring doesn't affect non overloaded functions.
module test;


fn foo() i32
{
	return 0;
}

fn main() i32
{
	func := foo;
	return func();
}
