//T macro:expect-failure
//T check:escape through assignment
module test;

global x: scope i32*;

fn main() i32
{
	y: scope i32* = null;
	x = y;
	return 0;
}
