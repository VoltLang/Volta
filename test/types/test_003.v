//T compiles:yes
//T retval:42
// Test implicit conversion from const using mutable indirection.
module test_003;

void foo(int i)
{
    return;
}

int main()
{
    const(int) i;
    foo(i);
    return 42;
}
