//T compiles:yes
//T retval:15
module test;


int main()
{
	// This tests that acc is not overwritten.
	int acc;

	void add(int val) {
		acc += 1; // Twice: 1, 1
		if (val > 1) {
			acc += 10; // Once: 10
			add(val - 1);
		}
		acc += val; // Twice: 2, 1
	}

	add(2); // (1 + 1) + (10) + (2 + 1) = 15
	return acc;
}
