//T compiles:yes
//T retval:42
// More function calling tests.
module test_017;

int outerFunc()
{
	return 2;
}

struct Struct
{
	int g;

	int other()
	{
		return 1;
	}

	int func()
	{
		return g + other() + outerFunc();
	}
}

class Clazz
{
	this()
	{
		return;
	}

	int g;

	int other()
	{
		return 1;
	}

	int func()
	{
		return g + other() + outerFunc();
	}
}

int main()
{
	Struct s;
	auto c = new Clazz();
	auto dg1 = s.func;
	auto dg2 = c.func;

	c.g = 3;
	s.g = 12;

	return c.func() + s.func() + dg1() + dg2();
}
