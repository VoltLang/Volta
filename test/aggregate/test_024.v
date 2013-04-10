//T compiles:yes
//T retval:45
// Overloading on class constructors.
module test_024;

class What
{
    this()
    {
        x = 7;
        return;
    }

    this(int y)
    {
        x = y;
        return;
    }

    this(bool b)
    {
        x = 40;
        return;
    }

    int x;
}

int main()
{
    auto a = new What(true);
    auto b = new What(5);
    return a.x + b.x;
}

