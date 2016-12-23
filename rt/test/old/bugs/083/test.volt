//T compiles:yes
//T retval:42
module test;

int main()
{
	char[] foo;
	string bar = "42";
	foo ~= bar;
	return 42;
}
