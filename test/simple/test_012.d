//T compiles:yes
//T retval:21
// Test transitive dereferencing.
module test_012;

int main()
{
	int i = 21;
	const p = &i;
	return *p;
}
