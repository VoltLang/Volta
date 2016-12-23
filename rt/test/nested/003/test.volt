//T compiles:yes
//T retval:12
module test;

int main() {
	int func() { return 12; }
	scope int delegate() dgt = func;
	return dgt();
}
