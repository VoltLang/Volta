//T compiles:yes
//T retval:1
module test;

enum A
{
	B, C, D
}

int main() {
	final switch (A.B) {
	case A.B:
		return 1;
	case A.C:
		return 5;
	case A.D:
		return 7;
	}
}

