module test;

class _class2
{
	protected:
		x: i32;
}

class child : _class2
{
	this(y: i32)
	{
		x = y;
	}

	fn get() i32
	{
		return x;
	}
}

fn main() i32
{
	c := new child(3);
	return c.x - 3;
}
