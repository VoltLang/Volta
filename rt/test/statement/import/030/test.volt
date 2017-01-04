//T default:no
//T macro:importfail
//T check:11:9: error: may not bind from private import, as 'ii' does.
module test;

import g;
import h;

fn main() i32
{
	return ii.x;
}
