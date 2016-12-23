//T compiles:yes
//T retval:42
module test;

interface Wow
{
	int doge();
}

union Union
{
	int foo;
	size_t bar;
}

class Such : Wow
{
	Union bad;

	override int doge()
	{
		return 42;
	}
}

int much(Wow wow)
{
	return wow.doge();
}

int main()
{
	return much(new Such());
}
