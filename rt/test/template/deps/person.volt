module person;

import core.exception;

private enum A = 25;

struct Person!(T)
{
	val: T;

	fn foo() i32
	{
		return val + A; 
		//throw new Exception("hello world");
	}
}
