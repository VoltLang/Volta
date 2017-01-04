// Test to see if destructors compile.
module test;

class Clazz
{
	this()
	{
	}

	~this()
	{
	}
}

class Clazz2
{
	~this()
	{
	}
}

fn main() i32
{
	return 0;
}
