//T macro:abi
//T check:declare void @func(double, i32, i64, i64)
//T requires:sysvamd64
module test;

struct S0
{
	a: f64;
	b: i32;
}

struct S1
{
	a: u32;
	b, c, d, e, f: u16;
	g: u8;
}

extern (C) fn func(a: S0, b: S1);
