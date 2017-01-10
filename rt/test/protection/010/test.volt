//T default:no
//T macro:importfail
//T check:access
module test;

import a;

fn main() i32
{
	s: _struct2;
	return s.x;
}

