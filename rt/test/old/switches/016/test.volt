//T compiles:yes
//T retval:0
module test;

class Foo
{
	enum Bar
	{
		A,
		B,
	}
}

int main()
{
	switch (4) with (Foo) {
	case Bar.A: return 1;
	default: return 0;
	}
}
