//T compiles:yes
//T retval:3
module test;


// Test that the long version is used and 0 and 1 is not
// implicitly converted to bool.
int func(bool) { return 0; }
int func(long) { return 1; }

int main()
{
	return func(0) + func(1) + func(2);
}
