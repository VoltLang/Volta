//T compiles:no
// Casting overloaded function.
module test;


int foo()
{
	return 27;
}

int foo(int a)
{
	return 45;
}

int main()
{
	auto fn = cast(int function()) foo;
	return fn();
}
