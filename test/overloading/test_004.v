//T compiles:yes
//T retval:27
// Ensure that overload erroring doesn't affect non overloaded functions.
module test_004;

int foo() { return 27; }

int main()
{
	auto fn = foo;
    return fn();
}
