//T compiles:no
module test;

fn main() i32
{
	int x = 12;
	global fn getX() i32
	{
		return x;
	}
	return getX();
}
