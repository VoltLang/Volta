//T compiles:no
// scope with MI to non scope.
module test_010;

int main()
{
    scope (int*) sip;
    int* ip = sip;
    return 0;
}
