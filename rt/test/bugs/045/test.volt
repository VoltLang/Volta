module test;

struct Struct
{
	field: i32;
}

struct Parent
{
	_struct: Struct;

	fn memberFunction()
	{
		fn nestedFunction()
		{
			_struct.field = 2;
			return;
		}
		return;
	}
}

fn main() i32
{
	return 0;
}

