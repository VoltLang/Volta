//T compiles:yes
//T retval:42
// Test string literals.
module test_004;

int sumArray(char[] str)
{
	uint sum;
	for (uint i; i < str.length; i++) {
		sum = sum + str[i];
	}
	return cast(int)sum;
}

int main()
{
	int val = sumArray("Volt");
	if (val == 421)
		return 42;
	else
		return 0;
}
