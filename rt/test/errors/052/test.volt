//T macro:expect-failure
module test;

fn main() i32
{
	fn foo() i32
	{
		return 12;
	}
	return foo();
}

alias StringStack = Foo