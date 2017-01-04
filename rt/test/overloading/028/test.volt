//T default:no
//T macro:expect-failure
//T check:2 overloaded functions match call
module test;

fn foo(a: i32) i32
{
	return 7;
}

fn foo(a: i32, b: i32 = 20) i32
{
	return a + b;
}

fn main() i32
{
	return foo(3);
}
 
