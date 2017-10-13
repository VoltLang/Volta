//T macro:abi
//T requires:win64
//T check:i32 @foo(%ac*)
module test;

extern (C) fn foo(str: string) i32
{
	return cast(i32)str.length;
}

fn main() i32
{
	return foo("");
}
