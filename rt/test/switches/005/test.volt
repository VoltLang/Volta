//T compiles:yes
//T retval:5
module test;

int main() {
	switch (2) {
	case 1, 2, 3:
		return 5;
	default:
		return 9;
	}
}

