//T macro:abi
//T check:define float @byVal(<2 x float>) #0 {
//T requires:sysvamd64
module test;

struct Colour
{
	a, b: f32;
}

extern (C) fn byVal(c: Colour) f32
{
	return c.b;
}
