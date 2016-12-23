//T compiles:no
// Invalid array allocation.
module test;

int main()
{
	int[] a;
	// array allocation, no concatenation (array) allowed.
	int[] b = new int[](3, a);

	return 0;
}
