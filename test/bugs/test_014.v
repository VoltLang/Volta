//T compiles:yes
//T retval:0
// Segfault due to declaration order, and null.
module test_014;

Foo func()
{
	return null; // This is what triggers it.
}

// If this class is defined the function it works
// But declared after as it is now, it causes a segfault.
class Foo
{
	this() { return; }
}

int main()
{
	return 0;
}
