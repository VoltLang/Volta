//T default:no
//T macro:importfail
//T check:access
module test;

import a;

fn main() i32
{
	s: _struct;
	return s.x;
}

