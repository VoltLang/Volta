//T requires:exceptions
module test;

import core.exception;

struct Definition!(T)
{
	a: T;

	fn foo() T
	{
		throw new Exception("a");
	}
}

struct Instance = mixin Definition!i32;

fn main() i32
{
	d: Instance;
	try {
		d.foo();
	} catch (Exception) {
		return 0;
	}
	return 1;
}
