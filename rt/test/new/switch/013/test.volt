// Enum switches from integer expressions.
module test;

enum Foo
{
	Baz,
	Bar,
}

fn main() i32
{
	Foo val = Foo.Bar;
	switch (cast(int)val) {
	case Foo.Bar:
		return 0;
	default:
		return 9;
	}
}
