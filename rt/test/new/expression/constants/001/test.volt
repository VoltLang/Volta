module test;

fn foo(x: i32 = __LINE__) i32
{
	return x;
}

fn main() i32
{
	return foo() + foo() - 20;
}
