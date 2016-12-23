//T compiles:yes
//T retval:42
// Static lookups in classes
module test;


class Foo
{
	this()
	{
		return;
	}

	enum int foo = 42;
}

int main()
{
	return Foo.foo;
}
