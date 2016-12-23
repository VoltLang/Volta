//T compiles:yes
//T retval:42
module test;

int main()
{
	// From D's static
	global int foo() {
		return 42;
	}

	return foo();
}
