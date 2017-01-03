module test;


class Foo
{
}

fn main() i32
{
	f := new Foo();

	// Should be able to call implicit constructors.
	f.__ctor();

	return 0;
}
