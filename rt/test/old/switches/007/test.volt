//T compiles:yes
//T retval:7
module test;

int main() {
	switch ("banana") {
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

