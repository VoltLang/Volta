//T macro:expect-failure
//T check:break
module test;

fn foo()
{
	break;
}

fn main() i32
{
	return 0;
}

