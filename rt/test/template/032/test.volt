//T default:no
//T macro:res
module test;

struct Definition!(T)
{
	a: T;

	fn foo() i32
	{
		a := import("empty.txt");
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

