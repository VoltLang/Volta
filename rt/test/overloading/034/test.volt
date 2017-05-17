module test;

import core.object;

class TestClass
{
	this(p: i32)
	{
		this.payload = p;
	}

	payload: i32;

	fn opCmp(obj: Object) i32	
	{
		auto tc = cast(TestClass)obj;
		if (payload > tc.payload) {
			return 1;
		} else if (payload < tc.payload) {
			return -1;
		} else {
			return 0;
		}
	}
}

fn main() i32
{
	one := new TestClass(1);
	two := new TestClass(2);
	ten := new TestClass(10);

	assert(one < two);
	assert(!(one > two));
	assert(two < ten);
	assert(ten > two && ten > one);
	assert(two > one);

	return 0;
}
