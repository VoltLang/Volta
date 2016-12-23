//T compiles:yes
//T retval:44
// Local variable shadowing member variable.
module test;


class Clazz
{
	int g;

	this(int g)
	{
		this.g = g;
		return;
	}

	int func(int g)
	{
		return this.g + g;
	}
}

int main()
{
	auto t = new Clazz(1);
	return t.g + t.func(42);
}
