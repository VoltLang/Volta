// Basic class stuff.
module test;


class Parent
{
	mField: i32;

	this(field: i32)
	{
		mField = field;
		return;
	}

	fn getField() i32
	{
		return mField;
	}
}

class Child : Parent
{
	this(field: i32)
	{
		super(field + 1);
		return;
	}
}

fn getResult(a: Parent, b: Parent) i32
{
	return a.getField() + b.getField();
}

fn main() i32
{
	a: Parent = new Parent(20);
	return getResult(a, new Child(21)) - 42;
}
