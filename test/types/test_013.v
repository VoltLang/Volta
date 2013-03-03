//T compiles:no
// Ensure that immutable can't become mutable through const.
module test_013;

void bar(char[])
{
    return;
}

void foo(const(char[]) a)
{
    bar(a);
    return;
}

int main()
{
    immutable(char[]) str;
    foo(str);
    return 0;
}
