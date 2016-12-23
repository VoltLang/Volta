//T compiles:yes
//T retval:42
module test;


int main()
{
	int[] ints = [2, 1, 0];

	int c;
	foreach_reverse (v; ints) {
		if (v != c++) {
			return 1;
		}
	}
	if (c != 3) {
		return 2;
	}

	foreach_reverse (i, v; ints) {
		if (cast(int)i != --c) {
			return 3;
		}
	}
	if (c != 0) {
		return 4;
	}

	return 42;
}
