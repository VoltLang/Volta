//T compiles:no
// Non overriding with methods in parent.
module test_014;

class Baz
{
    int xx() { return 2; }
}

class Bar : Baz
{
    override int x() { return 3; }
}

int main()
{
    auto foo = new Bar();
    return foo.x();
}
