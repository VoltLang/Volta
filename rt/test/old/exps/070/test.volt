//T compiles:yes
//T retval:1
module test;


int main()
{
	int[] arg = [3, 4, 5];
	size_t i = 0;

	// Make sure that side effects only happens once.
	arg = new arg[0 .. ++i];

	return cast(int)i;
}
