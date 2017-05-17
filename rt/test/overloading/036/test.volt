module test;

import core.object;

class TestClass
{
	this(p: i32)
	{
		this.payload = p;
	}

	payload: i32;

	fn opEquals(i: i32) bool
	{
		return i == payload;
	}
}

fn main() i32
{
	one := new TestClass(1);
	return 1 == one ? 0 : 1;
}
