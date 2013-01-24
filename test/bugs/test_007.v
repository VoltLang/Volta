//T compiles:yes
//T retval:42
//T has-passed:no
// Invalid escape.
module test_007;

int main()
{
	char[] arr = new char[1];
	t[0] = '\n';
	t[0] = '\0';

	char c = '\0';

	return 42;
}
