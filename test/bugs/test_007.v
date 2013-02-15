//T compiles:yes
//T retval:42
// Invalid escape.
module test_007;

int main()
{
	char[] arr = new char[](1);
	arr[0] = '\n';
	arr[0] = '\0';

	char c = '\0';

	return 42;
}
