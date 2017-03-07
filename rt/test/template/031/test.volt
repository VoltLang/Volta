module test;

struct Definition!(T)
{
	a: T;

	fn foo() i32
	{
		aa := ["hello": 0];
		return 0;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo();
}
