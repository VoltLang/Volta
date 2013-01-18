//T compiles:yes
//T retval:17
// non-MI to scope assignment.
module test_009;

int main()
{
    int i = 17;
    scope(int) si = i;
    return cast(int) si;
}
