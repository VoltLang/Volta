module test;

enum Enum { A, B, C }

fn main() i32
{
	e := Enum.B;
	switch (e) with (Enum) {
	default:
	case A, C: return 32;
	case B: return 0;
	}
	assert(false);
}

