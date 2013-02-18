//T compiles:no
module test_003;

@interface S
{
    string s;
}

@S(4) void foo()
{
    return;
}

int main()
{
    return 7;
}
