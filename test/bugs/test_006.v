//T compiles:yes
//T retval:42
//T has-passed:no
// Implicit converions doesn't work for binops.
module test_006;

int main()
{
	size_t t = 1;
	auto arr = new int[4];
	arr[0 .. t + 1];

	auto str = new char[1];
	str[0] = 20;

	return 42;
}
