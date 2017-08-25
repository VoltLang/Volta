//T macro:expect-failure
//T check:non-constant expression
module test;

struct TwoNumbers
{
	a, b: i32;
}

global c: i32 = 12;
global d: i32 = 3;

global tn: TwoNumbers = {c, d};

fn main() i32
{
	return tn.a + tn.b;
}
