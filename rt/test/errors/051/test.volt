//T macro:expect-failure
//T check:error
// This was another infinite loop, hence the vague check.
module test;

fn main() i32 {
	asm {
	return 0;
