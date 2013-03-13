//T compiles:no
// Test that named enums can not be explicitly typed.
module test_022;

enum named { int a; }

int main()
{
    return named.a;
}
