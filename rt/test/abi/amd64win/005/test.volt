//T macro:win64abi
//T requires:win64
//T check:i32 @testColour(i8*, i8*, i64, i8, i16)
// non integer coercion
module test;

struct ColourA
{
	a: u64;
}

struct ColourB
{
	a: u8;
}

struct ColourC
{
	a: u8;
	b: u8;
}

extern (C) fn testColour(a: void*, b: void*, colour: ColourA, cb: ColourB, cc: ColourC) i32;

fn main() i32
{
	ca: ColourA;
	ca.a = 34908;
	cb: ColourB;
	cb.a = 45;
	cc: ColourC;
	cc.a = 12;
	cc.b = 34;
	return testColour(null, null, ca, cb, cc);
}
