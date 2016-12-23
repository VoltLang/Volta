//T compiles:yes
//T retval:3
module test;

int main() {
	uint a, b;
	a = 0x8000_0000U;
	b = a >> 1U;
	if (b == 0x4000_0000) {
		return 3;
	} else {
		return 17;
	}
}

