//T compiles:no
// Non overriding with no parent.
module test_013;

class Bar
{
    override int x() { return 3; }
}

int main()
{
    auto foo = new Bar();
    return foo.x();
}
