//T default:no
//T macro:import
module test;

import theclass;

fn main() i32
{
	c := Class.basic();
	return c.field - 3;
}
