module test;

interface Foo
{
	fn func();
}

class Bar : Foo
{
	override fn func() {}
	fn func(foo: i32) {}
}

fn main() i32
{
	return 0;
}

