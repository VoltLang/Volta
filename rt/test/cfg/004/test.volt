module test;

import core.exception;

fn voidFunc(test: bool)
{
	if (test) {
		return;
	} else {
		test = true;
	}
}

fn main() i32
{
	voidFunc(false);
	return 0;
}
