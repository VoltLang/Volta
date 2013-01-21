//T compiles:yes
//T retval:42
module test_015;

class S {
    int mX;

    int y()
    {
        return mX;
    }
    void x(int _x)
    {
        mX = _x;
        return;
    }
}

int main()
{
    S s = new S();
    s.x(42);
    return s.y();
}
