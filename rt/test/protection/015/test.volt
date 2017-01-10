//T default:no
//T macro:import
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
	return c.get() - 3;
}
