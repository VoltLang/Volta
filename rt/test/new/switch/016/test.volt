module test;

class Foo
{
	enum Bar
	{
		A,
		B,
	}
}

fn main() i32
{
	switch (4) with (Foo) {
	case Bar.A: return 1;
	default: return 0;
	}
}
