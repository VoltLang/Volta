//T compiles:no
module test;

@label int add(int a, int b)
{
	return a + b;
}

int main()
{
	return add(16, 16);
}

