module test;

import core.exception;

struct Definition!(T)
{
	a: T;

	fn foo() T
	{
		foreach (i; 0 .. 10) {
			return cast(T)i;
		}
		assert(false);
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo();
}
