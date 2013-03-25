//T compiles:no
//T retval:27
// In sufficient function pointer assignment information.
module test_003;

int foo() { return 27; }
int foo(int a) { return 45; }

int main()
{
	auto fn = foo;
    return fn();
}
