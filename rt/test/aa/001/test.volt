//T compiles:yes
//T retval:42
// Basic AA test.
module test;


int main()
{
	int[int] aa;
	aa[3] = 42;
	return aa[3];
}
