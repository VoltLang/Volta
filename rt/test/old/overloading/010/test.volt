//T compiles:no
module test;


class What
{
	this()
	{
		return;
	}

	int foo()
	{
		return 5;
	}

	int foo(int x)
	{
		return 5 + x;
	}
}

class Child : What
{
	this()
	{
		return;
	}

	override int foo(int x)
	{
		return 10 + x;
	}
}

int main()
{
	auto what = new Child();
	return what.foo();
}
