//T compiles:yes
//T retval:27
// Function pointer assignment.
module test_002;

int foo() { return 27; }
int foo(int a) { return 45; }

int main()
{
	int function() fn = foo;
    return fn();
}
