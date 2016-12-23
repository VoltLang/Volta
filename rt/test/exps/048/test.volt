//T compiles:yes
//T retval:32
module test;

int foo(int a, int b)
{
	return (a + 2) * b;
}

int main()
{
	return foo(b:2, a:14);
}

