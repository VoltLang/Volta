//T compiles:yes
//T retval:15
module test;

int main() {
	int x = 3;
	int func() { return 12 + x; }
	return func();
}
