module test;

struct Foo
{
	global fn foo() i32
	{
		return 7;
	}
}

fn foo() i32
{
	return 12;
}

fn main() i32
{
	return (Foo.foo() + foo()) - 19;
}

