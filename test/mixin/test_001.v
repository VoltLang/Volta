//T compiles:yes
//T retval:42
// basic template mixin test.

module test_003;

mixin template Bar()
{
	int bar1() {}
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
