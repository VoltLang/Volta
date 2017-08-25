//T macro:import
module test;

import m1 : exportedVar1 = exportedVar;


fn main() i32
{
	return exportedVar1 - 42;
}
