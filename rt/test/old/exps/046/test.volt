//T compiles:yes
//T retval:32
module test;

int add(int a, int b)
{
	return a + b;
}

int main()
{
	return add(a:16, b:16);
}

