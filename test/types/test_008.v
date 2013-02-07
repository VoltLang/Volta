//T compiles:yes
// MI to scope assignment.
module test_008;

int main()
{
    int i = 42;
    int* ip = &i;
    scope(int*) sip = ip;
    return 0;
}
