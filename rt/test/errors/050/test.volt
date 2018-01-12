//T macro:expect-failure
//T check:error
// This was an infinite loop, hence the vague check.
module test;

fn main() i32 {
	foo := (
	return 0;
}
