//T compiles:yes
//T retval:28
// scope with MI to non scope.
module test_010;

int main()
{
    scope (int) si = 28;
    int i = si;
    return i;
}
