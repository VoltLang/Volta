//T compiles:no
// Test appending to an array, expected to fail.

module test_017;

int main()
{
	uint[] s;
	int i = 3;
	s = s ~ i;
}
