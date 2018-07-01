//T macro:importfail
//T check:unidentified identifier 'Exception'
module main;

import add;

fn integerAdder = mixin adder!i32;

fn main() i32
{
	return integerAdder(15, 15) - 55;
}
