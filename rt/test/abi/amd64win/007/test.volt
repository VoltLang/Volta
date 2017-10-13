//T macro:win64abi
//T requires:win64
//T check:i32 @testColour(i8*, i8*, i16)
// simple integer coercion
module test;

struct Internal
{
	a: u8[2];
}

struct Colour
{
	i: Internal;
}

extern (C) fn testColour(a: void*, b: void*, colour: Colour) i32;

fn main() i32
{
	c: Colour;
	c.i.a[0] = 3;
	c.i.a[1] = 7;
	return testColour(null, null, c) - 10;
}
