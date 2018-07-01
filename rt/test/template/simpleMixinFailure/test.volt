//T macro:importfail
//T check:tried to access private symbol 'A'
module main;

import person;

struct IntegerPerson = mixin Person!i32;

fn main() i32
{
	p: IntegerPerson;
	p.val = -25;
	return p.foo();
}
