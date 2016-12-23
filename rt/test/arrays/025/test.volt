//T compiles:yes
//T retval:42
// Array allocation and copy with new.
module test;

int main()
{
	int[] a = new int[](3);
	int[] b = [1, 2, 3];
	int[] c = new int[](a, b);

	if (c == [0, 0, 0, 1, 2, 3]) {
		return 42;
	}

	return 1;
}
