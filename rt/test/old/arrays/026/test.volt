//T compiles:no
// Invalid array allocation.
module test;

int main()
{
	int[] a;
	// array concatenation, only arrays allowed.
	int[] b = new int[](a, 3);

	return 0;
}
