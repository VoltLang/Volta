//T macro:expect-failure
//T check:circular dependency detected
// Alias circular dependency test.
module test;

struct Foo!(T)
{
	fn get() i32
	{
		return 32;
	}
}

struct Instance = mixin Foo!(Instance2);
struct Instance2 = mixin Foo!(Instance);

fn main() i32
{
	d: Instance;
	return d.get() - 32;
}
