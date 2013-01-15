//T compiles:yes
//T retval:42
//T has-passed:no
// Test implicit conversion from const using mutable indirection.
// Compiles but the resulting executable crashes. Probably due to the lack of conversion
// around const in the backend.
module test_006;

void foo(int i)
{
}

int main()
{
    const(int) i;
    foo(i);
    return 42;
}
