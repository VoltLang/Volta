//T macro:abi
//T check:define i8 @byVal(%S4test6Colour* byval) #0 {
//T requires:sysvamd64
module test;

struct Colour
{
	buf: u8[256];
}

extern (C) fn byVal(c: Colour) u8
{
	return c.buf[128];
}
