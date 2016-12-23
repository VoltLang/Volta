//T compiles:yes
//T retval:12
module test;

void foo(ref int x)
{
	x = 12;
}

int main()
{
	int y;
	foo(ref y);
	return y;
}

