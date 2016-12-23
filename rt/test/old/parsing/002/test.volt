//T compiles:yes
//T do-not-link
module test;

void foo() {
	version (none) {
		uniform!("[]", char, char)('0', '9');
	}
}

