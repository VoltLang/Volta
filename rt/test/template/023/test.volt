module test;

import core.exception;

struct Definition!(T)
{
	a: T;

	fn foo(dgt: fn() i32) i32
	{
		return dgt() + 2;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn bar() i32
{
	return -2;
}

fn main() i32
{
	d: Instance;
	return d.foo(bar);
}
