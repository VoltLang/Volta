//T compiles:yes
//T retval: 0
module test;

int main() {
	switch ("dst") {
	case "f32": return 2;
	default: return 0;
	}
}
