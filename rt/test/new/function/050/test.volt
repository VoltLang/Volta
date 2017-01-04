// @property assignment.
module test;


global mX: i32;

@property fn x(_x: i32)
{
	mX = _x;
	return;
}

fn main() i32
{
	x = 42;
	return mX - 42;
}
