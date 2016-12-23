//T compiles:no
module test;


int main()
{
	int f = 42;

	static void func() {
		// Static functions should not be able
		// to access function variables (or nested).
		f = 5;
	}
	func();

	return f;
}
