module test;

struct Definition!(T)
{
	a: T;

	fn foo() i32
	{
		a := typeid(T);
		return a.mutableIndirection ? -1 : 1;
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!i32*;

fn main() i32
{
	d: Instance;
	d2: Instance2;
	return d.foo() + d2.foo();
}
