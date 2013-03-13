//T compiles:yes
//T retval:2
// Test that enums can be implicitly casted to their base.
module test_021;

enum named { a, b, c, }

int main()
{
    return named.c;
}
