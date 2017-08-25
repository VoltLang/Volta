//T macro:expect-failure
module test;

struct Foo
{
	struct Blarg
	{
	}
}

fn main() i32
{
	f := Foo.Blarg + 3;

	return 0;
}
