//T compiles:yes
//T retval:42
module test_006;

int foo(int base, ...)
{
    return base + cast(int) _typeids[0].size + cast(int) _typeids[1].size;
}

int main()
{
    int i;
    short s;
    return foo(36, i, s);
}

