//T default:no
//T macro:expect-failure
//T check:no matching function to override
// Non overriding with methods in parent.
module test;


class Baz
{
	fn xx() i32
	{
		return 2;
	}
}

class Bar : Baz
{
	override fn x() i32
	{
		return 3;
	}
}

fn main() i32
{
	foo := new Bar();
	return foo.x();
}
