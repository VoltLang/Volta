//T compiles:no
// Prohibit shadowing.
module test_002;

int main()
{
    int x;
    if (true) {
        int x = 3;
        return x;
    } else {
        int x = 4;
        return x;
    }
}
