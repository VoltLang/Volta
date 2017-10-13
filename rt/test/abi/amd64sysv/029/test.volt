//T macro:abi
//T check:declare void @func(i64, i64)
//T requires:sysvamd64
module test;

struct S0
{
	struct S1 {
		struct S2 {
			a: i32;
		}
		y: S2[4];
	}
	x: S1[1];
}

extern (C) fn func(a: S0);
