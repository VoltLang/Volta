//T macro:expect-failure
//T check:unsupported feature
module test;

class A {}

fn foo(a: A[]...)
{
}

fn main() i32
{
	foo(null);
	return 0;
}
