//T compiles:no
module test;

int main()
{
    int add(int a, int b)
    {
        return 12;
    }

    int add(long c, long d)
    {
        return 24;
    }

    return add(12, 5);
}
