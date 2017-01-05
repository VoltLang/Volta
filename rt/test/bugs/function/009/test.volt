module test;

fn foo(s: string[]...) i32
{
	return 7;
}

fn foo(x: i32) i32
{
	return 9;
}

fn main() i32
{
	return 7 - foo("hello", "world");
}
