module test;

fn a(x: i32) i32
{
	return x;
}

fn a() i32
{
	return 7;
}

class SomeParent
{
	mX: i32;

	this(x: i32)
	{
		mX = x;
		return;
	}
}

class SomeChild : SomeParent
{
	this()
	{
		super(a());
		return;
	}
}

fn main() i32
{
	sc := new SomeChild();
	return sc.mX - 7;
}

