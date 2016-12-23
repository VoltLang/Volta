//T compiles:yes
//T retval:42
module test;


struct Test
{
	int val;

	void check(int should, int next)
	{
		if (val != should) {
			val = int.max;
		} else {
			val = next;
		}
	}
}

global Test test;


// Basic test.
void func1to2()
{
	scope (success) {
		test.check(1, 2);
	}
}

// Do test.
void func1to3()
{
	do {
		scope (success) {
			test.check(1, 2);
		}
		break;
	} while(false);

	scope (success) {
		test.check(2, 3);
	}
}

// Check continue and skipping of scopes.
void func1to4()
{
	int shouldBeOne;

	// Setup test for the second scope in for loop.
	test.check(1, 6);

	for (int i; i < 2; i++) {
		scope (success) {
			shouldBeOne = i;
		}

		if (i == 1) {
			// Check if continue triggers the right scope.
			continue;
		}

		// This shouldn't trigger the last loop.
		scope (success) {
			test.check(6, 1);
			shouldBeOne = 6;
		}
	}

	// This should trigger to late.
	scope (success) {
		shouldBeOne = 4;
	}

	test.check(1, 1);
	test.check(shouldBeOne, 4);
}

// Check trigger order.
void func1to5()
{
	// This should trigger last.
	scope (success) {
		test.check(3, 5);
	}
	// This should trigger first.
	scope (success) {
		test.check(2, 3);
	}

	test.check(1, 2);
}

// Switch
void func1to6()
{
	scope (success) {
		test.check(7, 6);
	}

	// Run order is. 0, 1, 3, 2, 3.
	for (int i; i < 4; i++) {
		switch (i) {
		case 0:
			test.check(1, 2);
			break;
		case 1:
			scope (success) {
				test.check(2, 3);
			}
			goto case 3;
		case 2:
			test.check(7, 3);
			break;
		case 3:
			scope (success) {
				test.check(3, 7);
			}
			break;
		default:
			// Should not be run.
			test.check(100, 0);
		}
	}
}

// Multiple levels with return.
void func1to7()
{
	scope (success) {
		test.check(4, 7);
	}
	scope (success) {
		test.check(3, 4);
	}

	for (int i; i < 4; i++) {
		scope (success) {
			test.check(2, 3);
		}
		scope (success) {
			test.check(1, 2);
		}
		// Should trigger all four scopes.
		return;
	}
}

void func1to8()
{
	scope (success) {
		test.check(4, 8);
	}

	return test.check(1, 4);
}

int main()
{
	// Init
	test.check(0, 1);

	func1to2();
	test.check(2, 1);

	func1to3();
	test.check(3, 1);

	func1to4();
	test.check(4, 1);

	func1to5();
	test.check(5, 1);

	func1to6();
	test.check(6, 1);

	func1to7();
	test.check(7, 1);

	func1to8();
	test.check(8, 1);

	if (test.val == 1) {
		return 42;
	} else {
		return 1;
	}
}
