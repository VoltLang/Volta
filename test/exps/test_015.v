//T compiles:yes
//T retval:13
// Simplest simple exptyper test is simple.
module test_015;

int main()
{
	return (true ? 6 : 3) + (false ? 3 : 7);
}
