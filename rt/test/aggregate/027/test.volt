//T default:no
//T macro:expect-failure
//T check:may not have an implementation
module test;


abstract class Foo
{
	abstract fn x() i32 { return 3; }
}

class Bar : Foo {}

fn main() i32
{
	return 0;
}
