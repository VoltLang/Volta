module test;

enum Enum
{
	A,
	B,
	C,
	D,
}

fn main() i32
{
	Enum e;
	final switch (e) {
	case Enum.A: return 0;
	case Enum.B: return 2;
	case Enum.C: assert(false);
	case Enum.D: return 5;
	}
	/* Never reached, no error generated. */
}

