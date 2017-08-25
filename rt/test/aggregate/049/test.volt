//T macro:importfail
//T check:access
module test;

import theclass;

fn main() i32
{
	c := new Class();
	return c.field - 3;
}
