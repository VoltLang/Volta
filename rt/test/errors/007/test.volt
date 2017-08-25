//T macro:expect-failure
//T check:is in use
module test;

alias A = i32;
global A: u32;

fn main() i32
{
	return 0;
}
