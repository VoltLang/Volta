//T macro:expect-failure
//T check:abstract classes like 'IntFoo'
module test;

abstract class Foo!(T)
{
	abstract fn get() T;

	fn GET() T
	{
		return get() * 10;
	}
}

class IntFoo = Foo!i32;

class Bar!(T, C) : C
{
	override fn get() T
	{
		return 2;
	}
}

class IntBar = Bar!(i32, IntFoo);

fn main() i32
{
	ib := new IntFoo();
	return ib.GET() - ib.get() - 18;
}
