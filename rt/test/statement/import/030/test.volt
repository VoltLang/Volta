//T macro:importfail
//T check:10:8: error: may not bind from private import, as 'ii' does.
module test;

import g;
import h;

fn main() i32
{
	return ii.x;
}
