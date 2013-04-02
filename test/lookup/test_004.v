//T compiles:yes
//T retval:3
module test_004;

class Foo
{
    int x;

    this()
    {
        return;
    }

    void func()
    {
        int x;
        return;
    }
}

int main() { return 3; }
