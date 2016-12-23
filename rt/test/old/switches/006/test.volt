//T compiles:yes
//T retval:5
module test;

int main() {
	switch (3) {
	case 1: .. case 3:
		return 5;
	default:
		return 9;
	}
}

