module test;

import core.exception;

enum A = 3;

struct Definition!(T)
{
	a: T;

	fn foo(arr: typeof(T)) T
	{
		return arr;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo(0);
}
