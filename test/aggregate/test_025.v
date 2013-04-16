//T compiles:no
// Creation of abstraction classes.
module test_025;

abstract class Foo
{
}

int main()
{
    auto foo = new Foo();
    return 0;
}
