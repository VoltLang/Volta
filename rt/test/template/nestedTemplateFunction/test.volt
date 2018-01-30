//T macro:expect-failure
//T check:non top level
module main;

fn add!(T)(a: T, b: T) T
{
	return cast(T)(a + b);
}

fn main() i32
{
	fn addShort = mixin add!i16;
	return addShort(1, 2);
}
