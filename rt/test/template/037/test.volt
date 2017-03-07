module test;

struct Definition!(T)
{
	a: T;

	fn foo() i32
	{
		if (is(T == i32)) {
			return 0;
		} else if (is(T == f32)) {
			return 1;
		} else {
			return 2;
		}
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance2;
	return d.foo() - 1;
}
