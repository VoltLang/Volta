//T compiles:yes
//T retval:42
// Test array comparison.

module test_012;

int main()
{
	string s1 = "Volt";
	string s2 = "Watt";
	string s3 = "Tesla";

	int[] i1 = [1, 2];
	int[] i2 = [3, 4, 5];
	int[] i3 = [6, 7, 8];

	if(s1 == s1 && s1 != s2 && s2 != s3 && !(s1 == s2) &&
	   i1 == i1 && i1 != i2 && i2 != i3 && !(i1 == i2))
		return 42;
	else
		return 0;
}
