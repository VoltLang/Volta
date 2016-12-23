//T compiles:no
// Invalid allocation with new auto.
module test;

int main()
{
	int[] x = new auto(3);

	return 1;
}
