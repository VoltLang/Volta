// Test implicit conversion from const using mutable indirection.
module test;

fn foo(i: i32)
{
}

fn main() i32
{
	i: const(i32);
	foo(i);
	return 0;
}