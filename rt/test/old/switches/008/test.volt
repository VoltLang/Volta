//T compiles:yes
//T retval:12
// Test that the default case works.
module test;

int main() {
	switch ("BANANA") {
	case "apple":
		return 1;
	case "banana":
		return 7;
	case "mango":
		return 9;
	default:
		return 12;
	}
}

