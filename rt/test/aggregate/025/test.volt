//T macro:expect-failure
//T check:may not be instantiated
// Creation of abstraction classes.
module test;


abstract class Foo
{
}

fn main() i32
{
	foo := new Foo();
	return 0;
}
