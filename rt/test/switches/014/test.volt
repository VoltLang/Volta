//T compiles:no
module test;

int main() {
	long[][] foo = [[cast(long)3, 3]];
	switch (foo) {
	case [[cast(long)3, 3]]:
		return 3;
	default:
		return 4;
	}
}
