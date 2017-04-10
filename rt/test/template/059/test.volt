module test;

struct Definition!(T)
{
	arr: T[];

	fn foo()
	{
		arr = null;
	}
}

struct Instance = mixin Definition!i32;

fn main() i32
{
	i: Instance;
	i.arr = [1,2,3];
	i.foo();
	return cast(i32)i.arr.length;
}
