module test;

import core.object : Object;


void func(obj: scope Object)
{
	static is (typeof(obj) == scope Object);

	var: typeof(obj);

	static is (typeof(var) == scope Object);
}

fn main() i32
{
	return 0;
}
