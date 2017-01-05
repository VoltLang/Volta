// Static lookups in classes
module test;


class Foo
{
	foo: i32;

	this()
	{
		foo = Bar.foo;
		return;
	}
}

class Bar
{
	enum i32 foo = 42;

	this()
	{
		return;
	}
}

fn main() i32
{
	f := new Foo();
	return f.foo - 42;
}
