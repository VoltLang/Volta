//T compiles:yes
//T retval:42
// Static lookups in classes
module test;


class Foo
{
	enum int foo = 21;

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
	auto f = new Foo();
	return f.func();
}
