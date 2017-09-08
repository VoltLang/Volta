//T macro:import
module test;

import core = m1;

fn main() i32
{
	return core.exportedVar - 42;
}
