// Static lookups in classes
module test;


class Foo
{
	enum i32 foo = 22;

	this()
	{
		return;
	}
}

class Bar
{
	enum i32 foo = 20;

	this()
	{
		return;
	}

	fn func() i32
	{
		return Foo.foo + foo;
	}
}

fn main() i32
{
	b := new Bar();
	return b.func() - 42;
}
