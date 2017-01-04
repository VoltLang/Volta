module test;

enum Foo
{
	VAL1 = 2,
	VAL2 = 40,
	VAL3 = 42,
}

enum val = Foo.VAL1 | Foo.VAL2;

fn main() i32
{
	flags: Foo = Foo.VAL3;

	return (flags & val) - 42;
}
