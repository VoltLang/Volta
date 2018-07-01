//T macro:import
module main;

import person;

struct IntegerPerson = Person!i32;

fn main() i32
{
	p: IntegerPerson;
	p.val = -25;
	return p.foo();
}
