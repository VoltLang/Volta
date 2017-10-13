//T macro:lin32abi
//T requires:lin32
// struct return sanity test
module test;

struct S
{
	x: i32;
}

extern (C) fn getTwelve() S;

fn main() i32
{
	s: S = getTwelve();
	return s.x - 12;
}

