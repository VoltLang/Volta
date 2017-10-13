//T macro:win64abi
//T requires:win64
//T check:i32 @testColour(i8*, i8*, %S4test6Colour*)
// non integer coercion
module test;

struct Colour
{
	a, b: u16;
	c: u8;
}

extern (C) fn testColour(a: void*, b: void*, colour: Colour) i32;

fn main() i32
{
	c: Colour;
	c.a = 32;
	c.b = 64;
	c.c = 16;
	return testColour(null, null, c);
}
