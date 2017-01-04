//T requires:exceptions
module test;

import core.exception;

fn foo()
{
	assert(false);
}

fn main() i32
{
	try {
		foo();
	} catch (AssertError) {
		return 0;
	}
	return 1;
}
