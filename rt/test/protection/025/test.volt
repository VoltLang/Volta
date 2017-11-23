//T macro:importfail
//T check:tried to access private symbol 'fuzzy'
module test;

import person;

global f: fuzzy;

fn main() i32
{
	return 0;
}
