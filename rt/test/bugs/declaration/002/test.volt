// Local variable shadowing member variable.
module test;


class Clazz
{
	g: i32;

	this(g: i32)
	{
		this.g = g;
		return;
	}

	fn func(g: i32) i32
	{
		return this.g + g;
	}
}

fn main() i32
{
	t := new Clazz(1);
	return t.g + t.func(42) - 44;
}
