//T compiles:yes
//T retval:17
// super postfix.
module test_018;

class Parent
{
    int x;

    this()
    {
        return;
    }
}

class Child : Parent
{
    this(int x)
    {
        super.x = 17;
        return;
    }
}

int main()
{
    auto child = new Child(42);
    return child.x;
}
