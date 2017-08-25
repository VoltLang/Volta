//T macro:expect-failure
module test;

fn main() i32
{
	int x = 0;
	global fn getX() i32
	{
		return x;
	}
	return getX();
}
