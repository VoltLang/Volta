//T compiles:yes
//T retval:3
module test;

int main() {
	int[] foo = [3, 3];
	switch (foo) {
	case [1, 1]:
		return 1;
	case [2, 2]:
		return 2;
	case [3, 3]:
		return 3;
	default:
		return 4;
	}
}
