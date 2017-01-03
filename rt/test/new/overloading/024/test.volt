module test;

interface Iface {}
class Foo : Iface
{
	this(Iface) {}
}

fn main() i32
{
	foo: Foo;

	// Fails to implicitly convert to Iface.
	new Foo(foo);

	return 0;
}
