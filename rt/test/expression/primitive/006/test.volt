// max and min aren't reserved words, make sure of it.
module test;

class SomeExcitingClassPancake
{
	max: i32;

	this(max: i32)
	{
		this.max = max;
	}
}

fn main() i32
{
	secp := new SomeExcitingClassPancake(42);
	return secp.max - 42;
}
