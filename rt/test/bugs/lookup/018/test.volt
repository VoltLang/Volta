//T macro:expect-failure
module test;

struct S
{
	_x: i32;

	@property fn x() i32
	{
		return _x;
	}
}

fn main() i32
{
	s: S;
	s.x = 12;
	return s.x;
}

