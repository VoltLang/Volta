//T compiles:yes
//T retval:7
module test;

int aNumber(int n = int.max)
{
	return n;
}

int main()
{
	if (aNumber() == int.max) {
		return 7;
	}
	return 3;
}

