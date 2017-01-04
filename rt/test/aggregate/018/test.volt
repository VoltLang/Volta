module test;


class A
{
	mX: i32;

	this(x: i32)
	{
		mX = x;
	}

	fn getX() i32
	{
		return mX;
	}
}

class B : A
{
	this(x: i32)
	{
		super(x + 1);
	}
}

fn main() i32
{
	b := new B(41);
	return b.getX() - 42;
}
