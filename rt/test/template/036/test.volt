module test;

struct S
{
	x: i32;
}

struct Definition!(T)
{
	a: T;

	fn foo() i32
	{
		s: S = {12};
		return s.x - 12;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!i32*;

fn main() i32
{
	d: Instance;
	return d.foo();
}
