//T compiles:yes
//T retval:42
// Test slicing and copying.

module test_005;


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
	int index = 3;
	auto ptr = new char;
	auto str = new char[4];

	str[] = "TheVoltIsAwesome"[index .. 7];
	ptr[0 .. 1] = "TheVoltIsAwesome"[index .. index+1];

	int val = sumArray(str);
	if (val == 421 && *ptr == 'V')
		return 42;
	else
		return 0;
}
