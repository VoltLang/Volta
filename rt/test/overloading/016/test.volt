//T compiles:no
// Test that top level functions cannot be marked override.
module test;


override int x()
{
	return 42;
}

int main()
{
	return x();
}
