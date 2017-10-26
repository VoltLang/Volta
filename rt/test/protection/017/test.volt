//T macro:importfail
//T check:23:8: error: tried to access
module test;

import a;

class child : _class2
{
	this(y: i32)
	{
		x = y;
	}

	fn get() i32
	{
		return x;
	}
}

fn main() i32
{
	c := new child(3);
	return c.x - 3;
}
