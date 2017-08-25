//T macro:expect-failure
//T check:unexpected array literal
module test;

fn foo(const(i32*))
{
	return;
}

fn main() i32
{
	foo([1,2,3]);
	return 0;
}

