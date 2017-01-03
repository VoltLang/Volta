//T default:no
//T macro:expect-failure
//T check:no matching function to override
// Non overriding with no parent.
module test;


class Bar
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
