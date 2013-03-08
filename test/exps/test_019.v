//T compiles:no
// Invalid super postfix.
module test_019;

class Parent
{
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
