//T macro:abi
//T check:define i32 @byVal(i64) #0 {
//T requires:sysvamd64
module test;

struct Colour
{
	a, b: i32;
}

extern (C) fn byVal(c: Colour) i32
{
	return c.b;
}
