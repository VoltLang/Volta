//T compiles:yes
//T retval:42
// Static lookups in classes
module test;


class Foo
{
	int foo;

	this()
	{
		foo = Bar.foo;
		return;
	}
}

class Bar
{
	enum int foo = 42;

	this()
	{
		return;
	}
}

int main()
{
	auto f = new Foo();
	return f.foo;
}
