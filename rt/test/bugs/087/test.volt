module test;

class Foo
{
	fn func() i32
	{
		return 42;
	}
}

fn foo(b: bool) Foo
{
	foo: Foo;
	// The assign in combination with ? fails.
	// It must be assign, decl assign works as well.
	foo = b ? new Foo() : null;

	// This works
	foo = (b ? new Foo() : null);
	return foo;
}

fn main() i32
{
	return foo(true).func() - 42;
}
