//T compiles:yes
//T retval:4
module test;

int main()
{
	int[] ints;
	int countToTen() {
		ints ~= countToTen();
		return 0;
	}
	return 4;
}

