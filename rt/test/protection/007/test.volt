//T default:no
//T macro:importfail
//T check:access
module test;

import a;

fn main() i32
{
	c := new _class();
	return c.x;
}

