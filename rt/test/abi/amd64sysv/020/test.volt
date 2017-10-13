//T macro:abi
//T check:declare i8* @func(i64, i8*)
//T requires:sysvamd64
module test;

struct S0
{
	x: i64;
	ptr: char*;
}

extern (C) fn func(s: S0) char*;
