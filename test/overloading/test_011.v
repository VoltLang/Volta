//T compiles:yes
//T retval:5
// Casting to parent and calling overloaded function.
module test_011;

class What
{
    this()
    {
        return;
    }

    int foo()
    {
        return 5;
    }

    int foo(int x)
    {
        return 5 + x;
    }
}

class Child : What
{
    this()
    {
        return;
    }

    override int foo(int x)
    {
        return 10 + x;
    }
}

int main()
{
    auto what = new Child();
    return (cast(What)what).foo();
}
