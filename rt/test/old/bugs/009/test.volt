//T compiles:yes
//T retval:6
module test;


@property int four() { return 4; }

class PlusTwoFactory
{
    int mX;

    this(int x)
    {
        mX = x + 2;
        return;
    }

    int get()
    {
        return mX;
    }
}

int main()
{
    auto factory = new PlusTwoFactory(four);
    return factory.get();
}
