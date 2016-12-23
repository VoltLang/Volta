//T compiles:yes
//T retval:32
module test;

void f(...) {
}

int main(string[] args) {
	void vdg() {}
	f(vdg);
	return 32;
}

