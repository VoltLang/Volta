module test;

struct S
{
	field: i32;

	fn opIndex(x: i32) i32
	{
		return x + field;
	}

	fn opAdd(right: S) S
	{
		_out: S;
		_out.field = field + right.field;
		return _out;
	}
}

fn main() i32
{
	a, b: S;
	a.field = 10;
	b.field = a[8];
	c := a + b;
	return c.field - 28;
}

