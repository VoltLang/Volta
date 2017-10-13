//T macro:abi
//T check:declare float @func(<2 x float>, float)
//T requires:sysvamd64
module test;

struct S0
{
	a, b, c: f32;
}

extern (C) fn func(a: S0) f32;
