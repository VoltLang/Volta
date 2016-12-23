//T compiles:yes
//T retval:42
// Test to see if destructors compile.
module test;

class Clazz
{
	this()
	{
		return;
	}

	~this()
	{
		return;
	}
}

class Clazz2
{
	~this()
	{
		return;
	}
}

int main()
{
	return 42;
}
