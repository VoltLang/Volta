//T compiles:yes
//T retval:3
module test;

int main() {
	long[] foo = [cast(long)3, 3];
	switch (foo) {
	case [cast(long)1, 1]:
		return 1;
	case [cast(long)2, 2]:
		return 2;
	case [cast(long)3, 3]:
		return 3;
	default:
		return 4;
	}
}
