//T compiles:yes
//T retval:42
// Most basic overloading test -- number of arguments.
module test;


int add(int a, int b)
{
	return a + b;
}

int add(int a, int b, int c)
{
	return a + b + c;
}

int main()
{
	return add(add(10, 10), 20, 2);
}
