module test;

struct Definition!(T)
{
	a: T;

	fn foo() i32
	{
		if (is(T == i32)) {
			return 3;
		} else if (is(T == f32)) {
			return -3;
		}
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	d2: Instance2;
	return d.foo() + d2.foo();
}
