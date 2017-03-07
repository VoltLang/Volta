module test;

struct Definition!(T)
{
	a: T;

	fn select(aa: string[]) i32
	{
		return cast(i32)aa[0].length - 5;
	}

	fn foo() i32
	{
		return select(["hello"]);
	}
}

struct Instance = mixin Definition!i32;
struct Instance2 = mixin Definition!f32;

fn main() i32
{
	d: Instance;
	return d.foo();
}
