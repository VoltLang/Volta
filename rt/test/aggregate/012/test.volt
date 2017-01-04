// Basic this stuff.
module test;


class First
{
	mField: i32;

	this(field: i32)
	{
		this.mField = field;
	}

	fn getField() i32
	{
		return this.mField;
	}
}

fn main() i32
{
	a: First = new First(42);

	return a.getField() - 42;
}
