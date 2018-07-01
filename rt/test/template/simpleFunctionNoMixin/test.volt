//T macro:import
module main;

import add;

fn integerAdder = adder!i32;

fn main() i32
{
	return integerAdder(15, 15) - 55;
}
