//T macro:expect-failure
module test;

class Foo
{
	x: i32;
}

fn main() i32
{
	with (new Foo()) {
		x = 2;
	}
	return 0;
}
