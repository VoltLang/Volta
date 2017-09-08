//T macro:importfail
//T check:redefine
module test;

import core = m1;

fn core() i32
{
	return 0;
}

fn main() i32
{
	return core.exportedVar - 42;
}
