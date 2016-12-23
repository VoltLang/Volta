//T compiles:no
// LValue checking is broken.
module test;


int main()
{
	int[] f = new int[4];
	auto t = &f[0 .. 5]; // Array slice is not a LValue

	return 42;
}
