//T default:no
//T macro:importfail
//T check:access
module test;

import a;

class child : _class2
{
	this(y: i32)
	{
		z = y;
	}

	fn get() i32
	{
		return z;
	}
}

fn main() i32
{
	c := new child(3);
	return c.get() - 3;
}
