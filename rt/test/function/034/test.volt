//T default:no
//T macro:expect-failure
module test;

import core.varargs;

extern (C) fn sum(...)
{
}

fn main() i32
{
	return 0;
}
