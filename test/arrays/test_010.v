//T compiles:yes
//T retval:42
// Test string concatenation.

module test_010;

int main()
{
    string s1 = "Volt";
    string s2 = "Watt";

    string result = s1 ~ s2;

    if(result.length == 8)
        return 42;
    else
        return 0;
}
