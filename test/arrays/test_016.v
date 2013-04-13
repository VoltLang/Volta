//T compiles:no
// Test appending to an array, expected to fail.

module test_016;

int main()
{
	float[] s;
	double i = 3.0;
	s = s ~ i;
}
