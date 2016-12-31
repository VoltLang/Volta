module test;

struct A
{
	a: i32[];
}

fn main() i32
{
	a, b: A;
	a.a = [1, 2, 3];
	b.a = new a.a[..];
	return (b.a[$-1] == 3) ? 0 : 1;
}
