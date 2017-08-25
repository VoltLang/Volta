//T macro:expect-failure
//T check:convert
module test;

class Foo {}
class Bar {}

fn main() i32
{
	f := new Foo[](1);
	arr: Bar[];
	arr ~= f;

	return 0;
}
