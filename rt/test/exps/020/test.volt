//T compiles:yes
//T retval:4
module test;


enum {
	a = 1,
	b = 7,
	c = 3,
}

int main()
{
	return a + c;
}
