module test;

fn foo(a: i32, b: i32 = 20) i32
{
	return a + b;
}

fn main() i32
{
	return foo(3) - 23;
}
 
