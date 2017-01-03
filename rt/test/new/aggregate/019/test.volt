module test;


enum
{
	a,
	b = 7,
	c,
}

enum d = 5;

fn main() i32
{
	return a + b + c + d - 20;
}
