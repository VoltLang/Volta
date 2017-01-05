// Segfault due to declaration order, and null.
module test;


fn func() Foo
{
	return null; // This is what triggers it.
}

// If this class is defined the function it works
// But declared after as it is now, it causes a segfault.
class Foo
{
	this() { return; }
}

fn main() i32
{
	return 0;
}
