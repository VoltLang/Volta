//T compiles:no
module test;

import core.varargs;

extern (C) fn sum(...)
{
}

fn main() i32
{
	return 0;
}
