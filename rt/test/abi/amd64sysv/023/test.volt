//T macro:abi
//T check:declare void @func(double, i32)
//T requires:sysvamd64
module test;

struct S0
{
	a: f64;
	b: i32;
}

extern (C) fn func(a: S0);
