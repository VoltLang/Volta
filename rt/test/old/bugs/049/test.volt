//T compiles:yes
//T retval:32
module test;

enum Enum { A, B, C }

int main()
{
	auto e = Enum.B;
	switch (e) with (Enum) {
	default:
	case A, C: return 0;
	case B: return 32;
	}
	assert(false);
}

