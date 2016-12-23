//T compiles:yes
//T retval:42
module test;

int addTogether(int a, int b)
{
	return a + b;
}

int main()
{
	int x = 41;
	int addTogether(int a)
	{
		return .addTogether(a, x);
	}
	return addTogether(1);
}

