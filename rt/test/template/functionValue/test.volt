module main;

fn getValue!(T, V: T)() T
{
	return V;
}

fn getInteger = mixin getValue!(i32, 10);

fn main() i32
{
	return getInteger() - 10;
}
