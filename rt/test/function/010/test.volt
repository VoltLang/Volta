//T default:no
//T macro:expect-failure
module test;

struct Struct
{
	field: i32;

	this(x: i32)
	{
		field = x;
	}

	this(x: i32, y: i32)
	{
		field = x + y;
	}
}

fn main()
{
	s: Struct;
	ss := s(12);
	return ss.field;
}
