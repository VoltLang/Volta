//T macro:abi
//T check:define i16 @byVal(i64, i64) #0 {
//T requires:sysvamd64
module test;

struct Colour
{
	a: u32;
	b, c, d, e, f: u16;
	g: u8;
}

extern (C) fn byVal(c: Colour) u16
{
	return c.b;
}
