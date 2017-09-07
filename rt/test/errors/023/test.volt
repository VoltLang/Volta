module test;

class A {}

fn foo(a: A[]...)
{
}

fn main() i32
{
	foo(cast(A)null);
	return 0;
}
