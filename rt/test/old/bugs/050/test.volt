//T compiles:yes
//T retval:0
module test;

struct Structure {
	void foo() {
	}
}

global Structure str;

int main() {
	void vdg() { str.foo(); }
	return 0;
}

