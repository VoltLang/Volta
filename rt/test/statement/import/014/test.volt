//T macro:import
module test;

import m1 : exportedVar1 = exportedVar;
import m2 : exportedVar2 = exportedVar;


fn main() i32
{
	return exportedVar1 + exportedVar2 - 74;
}
