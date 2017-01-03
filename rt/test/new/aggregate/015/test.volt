// Properties and classes and also a bug with multiple methods that we used to have.
module test;


class S
{
	mX: i32;

	this()
	{
	}

	@property fn y() i32
	{
		return mX;
	}
	@property fn x(_x: i32)
	{
		mX = _x;
	}
}

fn main() i32
{
	s: S = new S();
	s.x = 42;
	return s.y - 42;
}
