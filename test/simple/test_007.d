//T compiles:no
// Test implicit conversion from const using mutable indirection.
module test_006;

void foo(int* p)
{
}

int main()
{
    const(int*) ip;
    foo(ip);
    return 42;
}
