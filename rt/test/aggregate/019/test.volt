//T compiles:yes
//T retval:20
module test;


enum
{
	a,
	b = 7,
	c,
}

enum d = 5;

int main()
{
	return a + b + c + d;
}
