//T macro:import
module test;

import mod = m1;


fn main() i32
{
	return mod.exportedVar - 42;
}
