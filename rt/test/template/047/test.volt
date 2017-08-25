//T macro:expect-failure
//T check:banana
module test;

struct Foo!(K, V)
{
	static assert(false, "banana");
}

struct Instance = mixin Foo!(i32, i16);
struct Instance2 = mixin Foo!(f32, f32);

fn main() i32
{
	return 0;
}
