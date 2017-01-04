//T default:no
//T macro:expect-failure
//T check:2 overloaded functions match call
// Ambiguous overload set.
module test;


fn foo(a: i32, b: i32) i32
{
	return a + b;
}

fn foo(a: i32, b: i32) i32
{
	return a * b;
}

fn main() i32
{
	return foo(20, 22);
}
