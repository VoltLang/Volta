// Setting enum fields.
module test;

enum Foo
{
	FOO = 4,
}

class Bar
{
	var: Foo;

	fn func(a: Foo)
	{
		var = a;
		return;
	}
}

fn main() i32
{
	b := new Bar();
	b.func(Foo.FOO);

	return cast(i32)b.var - 4;
}
