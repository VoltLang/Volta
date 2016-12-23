//T compiles:no
// Test appending to an array, expected to fail.
module test;


int main()
{
	uint[] s;
	int i = 3;
	s ~= i;
}
