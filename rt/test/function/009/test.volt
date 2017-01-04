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

union Union
{
	field: i32;
	fald: i32;

	this(x: i32)
	{
		fald = x;
	}
}

fn main() i32
{
	s := Struct(12);
	y := Struct(2, 3);
	u := Union(2);
	return (s.field + y.field + u.field) - 19;
}
