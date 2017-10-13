//T macro:abi
//T check:declare void @func(i32, i64, i32)
//T requires:sysvamd64
module test;

struct S0
{
	a: i16;
	b: u32;
	c: i32;
}

extern (C) fn func(a: i32, s: S0);
