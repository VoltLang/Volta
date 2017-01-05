module test;

fn main() i32
{
	i: i32*;
	fn get() i32
	{
		x: i32 = *i;
		return x;
	}
	i = new i32;
	*i = 43;
	return get() - 43;
}

