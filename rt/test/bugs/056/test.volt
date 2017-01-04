module test;

fn foo(ref s: string)
{
	s = "hi";
}

fn foo(ref i: i32)
{
	i = 17;
}

fn main() i32
{
	x: i32;
	foo(ref x);
	return x - 17;
}

