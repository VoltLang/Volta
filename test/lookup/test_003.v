//T compiles:no
// Ensure for declarations don't leak.
module test_003;

int main()
{
    for (int x = 0; x < 10; x++) {
    }
    return x;
}
