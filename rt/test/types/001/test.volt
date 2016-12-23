//T compiles:no
// Test transitive dereferencing.
module test;


int main()
{
	int i = 42;
	const p = &i;
	*p = 42;
	return i;
}
