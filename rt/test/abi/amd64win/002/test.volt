//T macro:win64abi
//T requires:win64
//T check:i32 @testColour(i8*, i8*, i32)
// simple integer coercion
module test;

struct Colour
{
	r, g, b, a: u8;
}

extern (C) fn testColour(a: void*, b: void*, colour: Colour) i32;

fn main() i32
{
	c: Colour;
	c.r = 32;
	c.g = 64;
	c.b = 16;
	c.a = 128;
	return testColour(null, null, c);
}
