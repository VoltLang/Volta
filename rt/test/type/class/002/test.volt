//T default:no
//T macro:expect-failure
//T check:can not access fields and function variables via static lookups
// super postfix.
module test;


class Parent
{
	x: i32;

	this()
	{
	}
}

class Child : Parent
{
	this(x: i32)
	{
		// Right now it doesn't compile,
		// not sure if we want to support this anyways.
		super.x = 17;
	}
}

fn main() i32
{
	child := new Child(42);
	return child.x - 17;
}
