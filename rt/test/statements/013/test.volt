//T compiles:yes
//T retval:2
module test;


int main()
{
	// So that the value can escape the loop.
	int ret;

	for (int i; i <= 2; i++) {
		int f;

		// This should be 2 since f should be reset.
		// But it isn't reset so it gets the wrong value.
		f += i;

		// Escape the loop.
		ret = f;
	}

	return ret;
}
