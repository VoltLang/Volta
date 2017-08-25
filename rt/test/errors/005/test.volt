//T macro:expect-failure
//T check:5:11: error: @property functions with no arguments like 'foo' cannot have a void return type.
module test;

@property fn foo()
{
}

fn main() i32
{
	return 0;
}
