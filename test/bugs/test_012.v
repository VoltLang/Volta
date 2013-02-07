//T compiles:yes
//T retval:44
//T has-passed:no
// Local variable shadowing member variable.
module test_012;

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
