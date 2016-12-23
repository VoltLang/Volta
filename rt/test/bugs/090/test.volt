//T compiles:yes
//T retval:100
module test;


int[] foo()
{
	int[6] buf;
	buf[0] = 100;

	// If buf is a dynamic array this works, so its a static array thing.
	return new buf[0 .. $];
}

int main()
{
	return foo()[0];
}
