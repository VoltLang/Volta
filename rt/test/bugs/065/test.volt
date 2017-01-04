module test;

class C
{
	fn foo(a: i32[]...) i32
	{
		return a[0] + a[1];
	}
}

fn main() i32
{
	c := new C();
	return c.foo(3, 1) - 4;
}
