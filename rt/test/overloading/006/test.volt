// Casting non-overloaded function.
module test;


fn foo() i32
{
	return 0;
}

fn main() i32
{
	func := cast(fn() i32) foo;
	return func();
}
