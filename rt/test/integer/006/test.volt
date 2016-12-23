//T compiles:no
module test;


int main()
{
	bool foo;
	// Should not implicitly convert to a bool.
	foo = 0;
	return 0;
}
