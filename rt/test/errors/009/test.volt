//T macro:expect-failure
//T check:property function
module test;

@property fn foo() i32
{
	return 0;
}

fn main() i32
{
	return foo();
}
