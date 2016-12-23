//T compiles:no
module test;

int foo(int a, int b=2)
{
	return a + b;
}

int foo(int a)
{
	return a;
}

int main()
{
	return foo(12);
}
