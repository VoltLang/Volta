//T compiles:yes
//T retval:42
//Simple static array test.
module test;


int main()
{
	int[4] arg;
	arg[0] = 42;

	return arg[0];
}
