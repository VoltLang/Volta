//T compiles:yes
//T retval:14
// @property functions.
module test;


struct S
{
	@property int foo()
	{
		return 7;
	}

	@property int bar(int x)
	{
		return x * 2;
	}
}

int main()
{
	S s;
	return s.bar = s.foo;
}
