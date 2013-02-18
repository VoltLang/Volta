//T compiles:yes
//T retval:42
// Simple annotation test.
module test_002;


@interface Foo
{
	string value;
}

@Foo("bees!") void foo() { return; }

int main()
{
    foo();
    return 42;
}
