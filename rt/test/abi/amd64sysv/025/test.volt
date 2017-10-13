//T macro:abi
//T check:declare void @func(i64, i24)
//T requires:sysvamd64
module test;

struct S0
{
	a: u8[8];
	b: u8;
	c: u8;
	d: u8;
}

extern (C) fn func(a: S0);
