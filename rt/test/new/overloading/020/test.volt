module test;

class Base
{
	fn func() i32
	{
		return 2;
	}

	/// This is here to throw another spanner in the mix.
	fn overloaded() i32
	{
		return 20;
	}

	/// This is here to throw another spanner in the mix.
	fn overloaded(foo: i32) i32
	{
		return foo;
	}
}

class Sub : Base
{
	override fn func() i32
	{
		return 5;
	}

	override fn overloaded() i32
	{
		return 10;
	}


	fn test() i32
	{
		// 2 + 20 + 20 -> 42
		// 5 + 10 + 20 -> 35
		return super.func() + super.overloaded() + super.overloaded(20);
	}
}

fn main() i32
{
	s := new Sub();
	return s.test() - 42;
}
