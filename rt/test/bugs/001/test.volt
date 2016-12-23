//T compiles:yes
//T retval:42
// Segfault
module test;


int main()
{
	auto i = 0;
	auto id = typeid(typeof(i)); // Causes a segfault.

	return 42;
}
