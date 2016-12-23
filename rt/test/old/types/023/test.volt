//T compiles:no
// Simple in param test.
module test;


void foo(in int* foo)
{
	*foo = 42;
}

int main()
{
	int i;
	foo(&i);
	return i;
}
