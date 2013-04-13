//T compiles:no
// Test appending to an array, expected to fail.

module test_020;

int main()
{
	uint[] s;
	int i = 3;
	s ~= i;
}
