//T compiles:no
// final switch should only be valid for enums.
module test;

int main() {
	final switch (2) {
	case 1:
		return 1;
	case 2:
		return 5;
	case 3:
		return 7;
	}
}

