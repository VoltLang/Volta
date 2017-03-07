module test;

import core.varargs;

struct Foo!(T)
{
	fn get(val: T = 32) T
	{
		return val;
	}
}

struct Instance = mixin Foo!(i32);
struct Instance2 = mixin Foo!(f32);

fn main() i32
{
	d: Instance;
	return d.get() - 32;
}
