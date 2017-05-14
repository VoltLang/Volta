//T default:no
//T macro:import
module test;

import a;

fn main() i32
{
	return b.exportedVar - 42;
}
