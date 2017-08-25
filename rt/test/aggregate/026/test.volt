//T macro:expect-failure
//T check:may not have an implementation
module test;


class Foo
{
	abstract fn x() i32 { return 3; }
}

fn main() i32
{
	foo := new Foo();
	return 0;
}
