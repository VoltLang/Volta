//T macro:expect-failure
//T check:5:20: error:
module test;

fn foo(s: string = 42) i32
{
	return 0;
}

fn main() i32
{
	return foo();
}
