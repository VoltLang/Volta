//T compiles:yes
//T do-not-link
module test;

void foo() {
	version (none) {
		a.b!int();
	}
}

