//T compiles:yes
//T retval:42
// basic template mixin test.
module test;


mixin template Bar()
{
	int bar1()
	{
		return;
	}

	int bar2()
	{
		int x;
	}

	int bar3()
	{
		return 3;
	}
}

int main()
{
	return 42;
}
