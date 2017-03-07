module test;

import core.varargs;

struct Foo!(T)
{
	unittest
	{
		assert(true);
	}

	version (all) {
		x: T;
	}
}

struct Instance = mixin Foo!(i32);
struct Instance2 = mixin Foo!(f32);

fn main() i32
{
	d: Instance;
	return d.x;
}
