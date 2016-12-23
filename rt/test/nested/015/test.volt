//T compiles:yes
//T retval:42
module test;


// Function with nested function recursion.
int main()
{
	int func(int val) {
		// If case just to stop endless recursion, not needed.
		if (val == 42) {
			// Calling this function changes val.
			func(6);
			return val;
		} else {
			return 0;
		}
	}

	return func(42);
}
