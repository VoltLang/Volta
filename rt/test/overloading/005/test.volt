//T macro:expect-failure
//T check:cannot select
// Casting overloaded function.
module test;


fn foo() i32
{
	return 27;
}

fn foo(a: i32) i32
{
	return 45;
}

fn main() i32
{
	func := cast(fn() i32) foo;
	return func();
}
