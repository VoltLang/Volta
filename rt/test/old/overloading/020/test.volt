//T compiles:yes
//T retval:42
module test;

class Base
{
	int func()
	{
		return 2;
	}

	/// This is here to throw another spanner in the mix.
	int overloaded()
	{
		return 20;
	}

	/// This is here to throw another spanner in the mix.
	int overloaded(int foo)
	{
		return foo;
	}
}

class Sub : Base
{
	override int func()
	{
		return 5;
	}

	override int overloaded()
	{
		return 10;
	}


	int test()
	{
		// 2 + 20 + 20 -> 42
		// 5 + 10 + 20 -> 35
		return super.func() + super.overloaded() + super.overloaded(20);
	}
}

int main()
{
	auto s = new Sub();
	return s.test();
}
