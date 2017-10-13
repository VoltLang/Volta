//T macro:abi
//T check:define i8 @byVal(i32) #0 {
//T requires:sysvamd64
module test;

struct Colour
{
	r, g, b, a: u8;
}

extern (C) fn byVal(c: Colour) u8
{
	return c.b;
}
