//T compiles:no
// Test that abstract implementations must be marked as override.
module test;


abstract class Parent
{
	abstract int method();
}

class Child : Parent
{
	int method() { return 3; }
}

int main()
{
	return 3;
}
