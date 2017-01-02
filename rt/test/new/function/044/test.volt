module test;

fn foo(ref x: i32)
{
	x = 0;
}

fn main() i32
{
	y: i32 = 12;
	foo(ref y);
	return y;
}

