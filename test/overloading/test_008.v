//T compiles:no
// Ambiguous overload set.
module test_007;

int foo(int a, int b) { return a + b; }
int foo(int a, int b) { return a * b; }

int main()
{
    return foo(20, 22);
}
