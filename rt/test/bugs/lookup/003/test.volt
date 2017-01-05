// Static lookups in classes
module test;


class Foo
{
	enum i32 foo = 21;

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
	f := new Foo();
	return f.func() - 42;
}
