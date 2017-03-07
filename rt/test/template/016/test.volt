module test;

import core.exception;

struct Definition!(T)
{
	a: T;

	fn foo() T
	{
		try {
			return cast(T)0;
		} catch (e: Exception) {
			return cast(T)1;
		}
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo();
}
