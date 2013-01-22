//T compiles:yes
//T retval:42
// Most basic conditional test.
module test_001;

version(Volt)
	local int val;
version(none)
	int val;

int main()
{
	version(Volt)
		val = 42;
	version(none)
		val = 32;

	return val;
}
