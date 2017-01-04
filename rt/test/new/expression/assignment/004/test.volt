//T default:no
//T macro:expect-failure
//T check:may not remove their scope
module test;

global x: scope i32*;

fn main() i32
{
	y: scope i32* = null;
	x = y;
	return 0;
}
