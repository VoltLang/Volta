//T compiles:yes
//T retval:14
// @property functions.
module test_012;

struct S{
    @property int foo()
    {
        return 7;
    }

    @property int bar(int x)
    {
        return x * 2;
    }
}

int main()
{
    S s;
    return s.bar = s.foo;
}
