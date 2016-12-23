//T compiles:yes
//T retval:23
module test;

int foo(int a, int b = 20)
{
	return a + b;
}

int main()
{
	return foo(3);
}
 
