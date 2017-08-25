//T macro:import
module test;

import m1 : exportedVar;


fn main() i32
{
	return exportedVar - 42;
}
