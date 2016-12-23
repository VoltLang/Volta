//T compiles:no
module test;

enum A
{
	B, C, D
}

int main(A) {
	final switch (A.B) {
	case A.B:
		return 1;
	case A.C:
		return 5;
	}
}

