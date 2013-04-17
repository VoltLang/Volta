//T compiles:yes
//T retval:34
// Overriding with structs.
module test_015;

struct S
{
    int add(int a, int b)
    {
        return a + b;
    }

    float add(float a, float b)
    {
        return a;
    }
}

int main()
{
    S s;
    return s.add(32, 2);
}
