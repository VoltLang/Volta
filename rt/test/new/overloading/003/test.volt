//T default:no
//T macro:expect-failure
//T check:cannot select
// Insufficient function pointer assignment information.
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
	func := foo;
	return func();
}
