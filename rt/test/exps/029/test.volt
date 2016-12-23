//T compiles:yes
//T retval:42
// max and min aren't reserved words, make sure of it.
module test;

class SomeExcitingClassPancake
{
	int max;

	this(int max)
	{
		this.max = max;
		return;
	}
}

int main()
{
	auto secp = new SomeExcitingClassPancake(42);
	return secp.max;
}
