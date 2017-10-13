//T macro:abi
//T check:declare void @func(i32, i32)
//T requires:sysvamd64
module test;

struct S0
{
	a: i32;
}

extern (C) fn func(a: i32, b: S0);
