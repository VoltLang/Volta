module test;

import core.exception;

enum A = 3;

struct Definition!(T)
{
	a: T;

	fn foo(arr: T*) T
	{
		return *arr - 1;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	x := 1;
	return d.foo(&x);
}
