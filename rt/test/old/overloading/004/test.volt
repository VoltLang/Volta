//T compiles:yes
//T retval:27
// Ensure that overload erroring doesn't affect non overloaded functions.
module test;


int foo()
{
	return 27;
}

int main()
{
	auto func = foo;
	return func();
}
