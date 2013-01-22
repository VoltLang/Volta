//T compiles:yes
//T retval:42
// Test implicit conversion from const using mutable indirection doesn't prevent other conversions from occurring.
module test_005;

void foo(long i)
{
    return;
}

int main()
{
    const(int) i;
    foo(i);
    return 42;
}
