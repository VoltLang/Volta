//T macro:expect-failure
//T check:cannot implicitly convert
// Test implicit conversion from const using mutable indirection.
module test;


fn foo(p: i32*)
{
}

fn main() i32
{
	ip: const(i32*);
	foo(ip);
	return 42;
}
