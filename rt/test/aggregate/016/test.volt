//T compiles:yes
//T retval:42
// Generic function calling tests.
module test;

struct Struct
{
	int g;

	int func()
	{
		return g;
	}
}

class Clazz
{
	this()
	{
		return;
	}

	int g;

	int func()
	{
		return g;
	}
}

int main()
{
	Struct s;
	auto c = new Clazz();
	auto dg1 = s.func;
	auto dg2 = c.func;

	c.g = 6;
	s.g = 15;

	return c.func() + s.func() + dg1() + dg2();
}
