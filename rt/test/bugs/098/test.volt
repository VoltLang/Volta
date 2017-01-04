module test;

class Foo {}

fn bar(out var: Foo[])
{
	f: Foo;
	var ~= f;
}

fn main() i32
{
	return 0;
}
