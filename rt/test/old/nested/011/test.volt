//T compiles:no
module test;

int main()
{
	int foo(int x)
	{
		int bar(int x)
		{
			return x;
		}
		return bar(x);
	}
	return foo(32);
}
