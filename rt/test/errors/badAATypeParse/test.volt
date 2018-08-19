//T macro:expect-failure
//T check:mutably indirect
module test;

struct Struct
{
	alias key = size_t;
}

fn main() i32
{
	gFloatingNumbers: i32[Struct.key*];
	gFloatingNumbers[5] = 0;
	return gFloatingNumbers[5];
}
