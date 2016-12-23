//T compiles:yes
//T retval:0
module test;

global t: i32*;

fn foo(...) bool
{
	bar: i32;

	// Check if the save pointer is on the same place on the stack.
	// If it is null set the pointer.
	if (t is null) {
		t = &bar;
	} else if (t !is &bar) {
		return false;
	}

	return true;
}

fn main() i32
{
	i: u64;
	while (i < 4) {
		if (!foo(i++)) {
			return 1;
		}
	}
	return 0;
}