//T macro:expect-failure
//T check:cannot implicitly convert
module test;


fn main() i32
{
	c: char;
	p: scope i32*;
	p = &c;
	return 0;
}
