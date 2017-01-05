// Can't call functions from member functions.
module test;


fn func()
{
}

class Test
{
	this()
	{
	}

	fn myFunc()
	{
		// Thinks func is a member on Test.
		func();
	}
}

fn main() i32
{
	return 0;
}
