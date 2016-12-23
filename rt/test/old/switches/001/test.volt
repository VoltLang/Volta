//T compiles:yes
//T retval:5
module test;

int main() {
	switch (2) {
	case 1:
		return 1;
	case 2:
		return 5;
	case 3:
		return 7;
	default:
		return 9;
	}
}

