//T macro:abi
//T check:void @func(%S4test2S0* sret, i32, i32, i32, i32, %S4test2S1, i32)
//T requires:sysvamd64
// Check that register exhaustion accounts for struct return.
module test;

struct S0
{
	a, b, c: u64;
}

struct S1
{
	a, b: i64;
}

extern (C) fn func(a: i32, b: i32, c: i32, d: i32, s: S1, f: i32) S0;
