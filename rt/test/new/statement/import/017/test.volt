//T default:no
//T macro:import
module test;

import ctx = m1 : exportedVar1 = exportedVar;


fn main() i32
{
	return ctx.exportedVar1 - 42;
}
