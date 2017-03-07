module test;

import core.exception;

struct Definition!(T)
{
	a: T;

	fn foo(v: const(T)) const(T)
	{
		return v - 1;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo(1);
}
