module test;

import core.exception;

struct Definition!(T)
{
	a: T;

	fn foo(arr: i32[3]) i32
	{
		return arr[0] + arr[2];
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo([3, 0, -3]);
}
