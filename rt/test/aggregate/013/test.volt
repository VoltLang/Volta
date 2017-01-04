// Inheritance class stuff.
module test;


class Parent
{
	this()
	{
		return;
	}

	mField: i32;
}

class Child : Parent
{
	this(field: i32)
	{
		mField = field;
	}

	fn getField() i32
	{
		return this.mField;
	}
}

fn main() i32
{
	a: Child = new Child(42);

	return a.getField() - 42;
}
