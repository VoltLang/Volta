//T macro:expect-failure
//T check:tried to assign a void value
module test;

fn foo()
{
}

fn main() i32
{
	bar := foo();
	return 0;
}
