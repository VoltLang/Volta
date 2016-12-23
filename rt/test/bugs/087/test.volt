//T compiles:yes
//T retval:42
module test;

class Foo
{
	int func()
	{
		return 42;
	}
}

Foo foo(bool b)
{
	Foo foo;
	// The assign in combination with ? fails.
	// It must be assign, decl assign works as well.
	foo = b ? new Foo() : null;

	// This works
	foo = (b ? new Foo() : null);
	return foo;
}

int main()
{
	return foo(true).func();
}
