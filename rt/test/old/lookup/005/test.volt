//T compiles:yes
//T retval:19
module test;

struct Foo
{
	static int foo()
	{
		return 7;
	}
}

int foo()
{
	return 12;
}

int main()
{
	return Foo.foo() + foo();
}
