// Inheritance class stuff.
module test;


class AnotherParent
{
	this()
	{
	}

	mField: i32;

	fn addToField(val: i32)
	{
		this.mField = mField + val;
	}
}

class Parent : AnotherParent
{
	this()
	{
	}
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
	a: Child = new Child(20);
	a.addToField(22);
	return a.getField() - 42;
}
