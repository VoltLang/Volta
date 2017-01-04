module test;

struct TwoNumbers
{
	a, b: i32;
}

fn main() i32
{
	c: i32 = 12;
	d: i32 = 3;
	tn: TwoNumbers = {c, d};
	return tn.a + tn.b - 15;
}
