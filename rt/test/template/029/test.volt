module test;

struct Definition!(T)
{
	a: T;

	fn select(aa: i32[string]) i32
	{
		return aa["hello"];
	}

	fn foo() i32
	{
		return select(["hello":0]);
	}
}

struct Instance = mixin Definition!i32;

fn main() i32
{
	d: Instance;
	return d.foo();
}
