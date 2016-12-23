//T compiles:yes
//T retval:6
module test;

struct c {}

int main()
{
	c* d;
	int a = 2, b = 3;
	(a * b);
	return a * b;
}

