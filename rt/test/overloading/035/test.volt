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
		return opCmp(tc.payload);
	}

	fn opCmp(i: i32) i32
	{
		if (payload > i) {
			return 1;
		} else if (payload < i) {
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

	assert(one < 2);
	assert(!(one > 2));
	assert(two < 10);
	assert(ten > 2 && ten > 1);
	assert(two > 1);
	assert(1 < two);
	assert(!(1 > two));
	assert(10 > two && 10 > one);

	return 0;
}
