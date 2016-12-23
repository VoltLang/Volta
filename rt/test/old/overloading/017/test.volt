//T compiles:no
// Test that non class members cannot be marked override.
module test;


struct S
{
	override int x()
	{
		return 42;
	}
}

int main()
{
	S s;
	return s.x();
}
