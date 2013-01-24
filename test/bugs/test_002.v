//T compiles:no
// scope and '&' causes pointers to be accepted when it shouldn't.
module test_002;

void func(scope char* t)
{
	return;
}

int main()
{
	int argz;
	// Removing scope above also fixes the issue.
	func(&argz); // Clearly the wrong type here.

	// int* argz;
	// func(argz); // Fails as expected.
	return 42;
}
