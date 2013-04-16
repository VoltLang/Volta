//T compiles:no
module test_026;

class Foo
{
    abstract int x() { return 3; }
}

int main()
{
    auto foo = new Foo();
    return 0;
}
