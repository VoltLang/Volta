//T macro:warnings
//T check:assigning y to itself
//T check:assigning j to itself
module main;

struct Si
{
	x: i32;
	y: i32;

	fn copy() Si
	{
		s: Si;
		s.x = x;
		y = y;
		return s;
	}
}

fn main() i32
{
	i: Si;
	i.x = 12;
	j := i.copy();
	j = j;
	return j.x - 12;
}
