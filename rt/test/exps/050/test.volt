//T compiles:yes
//T retval:35
module test;

int add(int a, int b, int c = 3)
{
	return a + b + c;
}

int main()
{
	return add(a:16, b:16);
}

