//T macro:warnings
//T check:y to itself
module main;

struct Sl
{
	y: i32;
}

struct Si
{
	x: i32;
	l: Sl;
}

fn main() i32
{
	i: Si;
	i.l.y = i.l.y;
	return 0;
}
