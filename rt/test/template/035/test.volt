module test;

fn bar() i32
{
	return 0;
}

struct Definition!(T)
{
	a: T;

	fn foo() i32
	{
		return #run bar();
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!i32*;

fn main() i32
{
	d: Instance;
	return d.foo();
}
