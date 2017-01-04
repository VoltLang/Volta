//T default:no
//T macro:import
module test;

import ir = m12;

fn main() i32
{
	return cast(int) ir.retval - 41;
}

