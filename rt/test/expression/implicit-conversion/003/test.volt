// Test implicit conversion from const using mutable indirection doesn't prevent other conversions from occurring.
module test;


fn foo(i: i64)
{
}

fn main() i32
{
	i: const(i32);
	foo(i);
	return 0;
}
