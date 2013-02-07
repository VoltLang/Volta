//T compiles:yes
//T retval:42
// Test string comparison.

module test_012;

int main()
{
	string s1 = "Volt";
	string s2 = "Watt";

	int[] i1 = [1, 2];
	int[] i2 = [3, 4, 5];

	if(s1 == s1 && s1 != s2 && i1 == i2 && i1 != i2)
		return 42;
	else
		return 0;
}
