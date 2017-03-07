module test;

import core.exception;

struct Definition!(T)
{
	a: T;

	fn foo(aa: i32[string]) i32
	{
		return aa["hello"];
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	aa: i32[string];
	aa["hello"] = 0;
	d: Instance;
	return d.foo(aa);
}
