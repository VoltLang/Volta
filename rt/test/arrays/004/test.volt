//T compiles:yes
//T retval:42
// Test slicing.
module test;


int sumArray(const(char)[] str)
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
	int val = sumArray("TheVoltIsAwesome"[index .. 7]);
	if (val == 421)
		return 42;
	else
		return 0;
}
