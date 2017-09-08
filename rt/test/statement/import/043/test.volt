//T macro:import
module test;

import foo.bar.baz;
import foo = m1;

fn main() i32
{
	return foo.exportedVar - 42;
}
