//T default:no
//T macro:expect-failure
//T check:cannot select
// Function pointer assignment.
module test;


fn foo() i32
{
	return 0;
}

fn foo(a: i32) i32
{
	return 45;
}

fn main() i32
{
	func: fn() i32 = foo;
	return func();
}
