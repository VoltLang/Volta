//T compiles:no
// Ensure that immutable can't become const.
module test_013;

void foo(const(char[]))
{
    return;
}

int main()
{
    immutable(char[]) str;
    foo(str);
    return 0;
}
