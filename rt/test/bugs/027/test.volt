//T compiles:yes
//T retval:42
// Static lookups in classes
module test;


class Foo
{
	enum int foo = 22;

	this()
	{
		return;
	}
}

class Bar
{
	enum int foo = 20;

	this()
	{
		return;
	}

	int func()
	{
		return Foo.foo + foo;
	}
}

int main()
{
	auto b = new Bar();
	return b.func();
}
