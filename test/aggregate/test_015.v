//T compiles:yes
//T retval:42
// Properties and classes and also a bug with multiple methods that we used to have.
module test_015;

class S {
    int mX;

    this()
    {
        return;
    }

    @property int y()
    {
        return mX;
    }
    @property void x(int _x)
    {
        mX = _x;
        return;
    }
}

int main()
{
    S s = new S();
    s.x = 42;
    return s.y;
}
