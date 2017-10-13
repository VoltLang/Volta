//T macro:abi
//T check:declare void @func(<2 x float>, <2 x float>)
//T requires:sysvamd64
module test;

struct S0
{
	a, b, c, d: f32;
}

extern (C) fn func(a: S0);
