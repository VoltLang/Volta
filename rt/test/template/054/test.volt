//T default:no
//T macro:expect-failure
//T check:expected type
module test;

struct Bar!(T)
{
}

struct Foo!(T)
{
	fn get() i32
	{
		return 32;
	}
}

struct Instance = mixin Foo!(Bar);

fn main() i32
{
	d: Instance;
	return d.get() - 32;
}
