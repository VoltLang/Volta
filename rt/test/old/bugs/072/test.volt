//T compiles:yes
//T retval:7
module test;

enum Enum
{
	A,
	B,
	C,
	D,
}

int main()
{
	Enum e;
	final switch (e) {
	case Enum.A: return 7;
	case Enum.B: return 2;
	case Enum.C: assert(false);
	case Enum.D: return 5;
	}
	/* Never reached, no error generated. */
}

