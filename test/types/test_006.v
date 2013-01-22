//T compiles:no
//T retval:42
// Test implicit conversion from const doesn't allow invalid conversions to occur.
module test_006;

void foo(short i)
{
    return;
}

int main()
{
    const(int) i;
    foo(i);
    return 42;
}
