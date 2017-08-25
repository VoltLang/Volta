//T macro:expect-failure
//T check:continue
module test;

fn foo()
{
	continue;
}

fn main() i32
{
	return 0;
}

