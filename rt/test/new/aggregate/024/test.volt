// Overloading on class constructors.
module test;


class What
{
	this()
	{
		x = 7;
	}

	this(y: i32)
	{
		x = y;
	}

	this(b: bool)
	{
		x = 40;
	}

	x: i32;
}

fn main() i32
{
	a := new What(true);
	b := new What(5);
	return a.x + b.x - 45;
}
