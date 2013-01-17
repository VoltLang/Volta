//T compiles:no
// Test transitive dereferencing.
module test_011;

int main()
{
	int i = 42;
	const p = &i;
	*p = 42;
	return i;
}
