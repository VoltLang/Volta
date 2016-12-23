//T compiles:yes
//T retval:4
module test;


int main()
{
	// Segfaults the compiler
	// Just turn this into a while(true)
	for (;;) {
		return 4;
	}
	return 42;
}
