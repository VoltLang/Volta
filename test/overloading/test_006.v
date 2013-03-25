//T compiles:yes
//T retval:27
// Casting non-overloaded function.
module test_006;

int foo() { return 27; }

int main()
{
	auto fn = cast(int function()) foo;
    return fn();
}
