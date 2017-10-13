//T macro:abi
//T check:define i8 @byVal(i64, i40) #0 {
//T requires:sysvamd64
module test;

struct Colour
{
	a,b,c,d,  e,f,g,h,  i,j,k,l,  m: u8;
}

extern (C) fn byVal(c: Colour) u8
{
	return c.b;
}
