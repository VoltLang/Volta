//T default:no
//T macro:import
module test;

import ctx = m1;


fn main() i32
{
	return ctx.exportedVar - 42;
}
