//T compiles:yes
//T retval:42
//T has-passed:no
// Implicit int conversion gone wrong.
module test_021;

int main()
{
	ubyte t = 4;
	if (t == 4)
		return 42;
	return 0;
}
