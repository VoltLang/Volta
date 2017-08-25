//T macro:expect-failure
//T check:expected static array literal of length 2
module test;

fn foo(a: i32[2]) i32
{
	return a[0] + a[1];
}

fn foo(s: string) i32
{
	return cast(i32)s.length;
}

fn main() i32
{
	return foo([19, 8, 6]);
}
