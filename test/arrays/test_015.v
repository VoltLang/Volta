//T compiles:no
// Test appending to an array, expected to fail.

module test_015;

int main()
{
	short[] s;
	int i = 3;
	s = s ~ i;
}
