//T compiles:no
module test;

int foo(int a)
{
	return 7;
}

int foo(int a, int b = 20)
{
	return a + b;
}

int main()
{
	return foo(3);
}
 
