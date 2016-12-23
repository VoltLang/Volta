//T compiles:yes
//T retval:27
// Casting non-overloaded function.
module test;


int foo()
{
	return 27;
}

int main()
{
	auto func = cast(int function()) foo;
	return func();
}
