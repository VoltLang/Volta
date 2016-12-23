//T compiles:yes
//T retval:12
module test;

fn main() i32
{
	int x = 12;
	fn getX() i32
	{
		return x;
	}
	return getX();
}
