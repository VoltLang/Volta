//T macro:abi
//T check:declare void @func2(i32, i32, i32, i32, i32, i32, i32)
//T requires:sysvamd64
// clang test47
module test;

struct S0
{
	a: i32;
}

extern (C) fn func2(a: i32, b: i32, c: i32, d: i32,
	e: i32, f: i32, s: S0);

extern (C) fn func(a: i32, b: S0)
{
	func2(a, a, a, a, a, a, b);
}
