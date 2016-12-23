//T compiles:yes
//T retval:13
module test;

int sum(bool ignored, int[] integers...)
{
	int retval;
	for (size_t i = 0; i < integers.length; i++) {
		retval += integers[i];
	}
	return retval;
}

int main()
{
	int x = 3;
	auto a = [1, 2, 3];
	return sum(true, 1, x, 3) + sum(false, a);
}

