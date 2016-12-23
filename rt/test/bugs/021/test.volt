//T compiles:yes
//T retval:42
// Implicit int conversion gone wrong.
module test;


int main()
{
	ubyte t = 4;
	if (t == 4)
		return 42;
	return 0;
}
