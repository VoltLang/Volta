// Tests no arg @property and calling into structs.
module test;


struct S
{
	mX: i32;

	@property fn x(_x: i32)
	{
		mX = _x;
	}

	@property fn y() i32
	{
		return mX;
	}
}

fn main() i32
{
	s: S;
	s.x = 42;
	return s.y - 42;
}
