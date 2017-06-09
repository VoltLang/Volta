module test;

struct S
{
	integerHoldingDevice: i32;
}

fn funk(s: S, i: i32) i32
{
	return s.integerHoldingDevice + i;
}

fn main() i32
{
	s: S;
	s.integerHoldingDevice = -3;
	return s.funk(i:3);
}
