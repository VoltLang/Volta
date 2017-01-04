// Static lookups in classes
module test;


class Foo
{
	this()
	{
		return;
	}

	enum i32 foo = 42;
}

fn main() i32
{
	return Foo.foo - 42;
}
