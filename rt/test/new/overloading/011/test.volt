// Casting to parent and calling overloaded function.
module test;


class What
{
	this()
	{
		return;
	}

	fn foo() i32
	{
		return 0;
	}

	fn foo(x: i32) i32
	{
		return 5 + x;
	}
}

class Child : What
{
	this()
	{
		return;
	}

	override fn foo(x: i32) i32
	{
		return 10 + x;
	}
}

fn main() i32
{
	what := new Child();
	return (cast(What)what).foo();
}
