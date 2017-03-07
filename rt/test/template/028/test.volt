module test;

struct Definition!(T)
{
	a: T;

	fn foo(b: bool) i32
	{
		return b ? 0 : 1;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo(!false);
}
