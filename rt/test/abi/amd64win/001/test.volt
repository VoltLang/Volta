//T macro:win64abi
//T requires:win64
//T check:@getZero()
// win64abi sanity test
module test;

extern (C) fn getZero() i32;

fn main() i32
{
	return getZero();
}