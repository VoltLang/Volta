//T compiles:yes
//T retval:42
module test;

interface Iface {}
class Foo : Iface
{
	this(Iface) {}
}

int main()
{
	Foo foo;

	// Fails to implicitly convert to Iface.
	new Foo(foo);

	return 42;
}
