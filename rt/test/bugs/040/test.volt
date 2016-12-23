//T compiles:yes
//T retval:42
module test;

class Foo
{
	int func1(const(char)[] f)
	{
		return dummy(f);
	}

	int func2(const(char)* f)
	{
		return dummy(f);
	}
}

int dummy(const(char)[] f)
{
	return 20;
}

int dummy(const(char)* f)
{
	return 22;
}

int main()
{
	auto f = new Foo();
	return f.func1(null) + f.func2(null);
}
