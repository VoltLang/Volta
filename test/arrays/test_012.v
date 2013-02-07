//T compiles:yes
//T retval:42
// Test string comparison.

module test_012;

int main()
{
	string s1 = "Volt";
	string s2 = "Watt";

	if(s1 == s1 && s1 != s2)
		return 42;
	else
		return 0;
}
